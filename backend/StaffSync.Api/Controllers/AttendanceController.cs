using Google.Cloud.Firestore;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.SignalR;
using StaffSync.Api.Hubs;
using StaffSync.Api.Models;

namespace StaffSync.Api.Controllers;

[ApiController]
[Route("api/attendance")]
[Authorize]
public class AttendanceController : ControllerBase
{
    private readonly FirestoreDb _db;
    private readonly IHubContext<AttendanceHub> _hub;

    public AttendanceController(FirestoreDb db, IHubContext<AttendanceHub> hub)
    {
        _db = db;
        _hub = hub;
    }

    [HttpPost("mark")]
    public async Task<IActionResult> MarkAttendance([FromBody] AttendanceMarkRequest request)
    {
        if (string.IsNullOrWhiteSpace(request.UserId))
        {
            return BadRequest("UserId required.");
        }

        var timestamp = request.TimestampUtc == default ? DateTime.UtcNow : request.TimestampUtc;
        var data = new Dictionary<string, object?>
        {
            ["userId"] = request.UserId,
            ["timestampUtc"] = timestamp,
            ["latitude"] = request.Latitude,
            ["longitude"] = request.Longitude,
            ["status"] = string.IsNullOrWhiteSpace(request.Status) ? "present" : request.Status
        };

        var docRef = await _db.Collection("attendance").AddAsync(data);
        await _hub.Clients.All.SendAsync("attendanceUpdated", request.UserId, new { id = docRef.Id, data });

        return Ok(new { id = docRef.Id });
    }

    [HttpPost("mark-batch")]
    [Authorize(Policy = "Admin")]
    public async Task<IActionResult> MarkBatch([FromBody] AttendanceBatchMarkRequest request)
    {
        if (request.Records == null || request.Records.Count == 0)
        {
            return BadRequest("Records required.");
        }

        var created = 0;
        foreach (var record in request.Records)
        {
            if (string.IsNullOrWhiteSpace(record.UserId))
            {
                return BadRequest("UserId required.");
            }

            var timestamp = record.TimestampUtc == default ? DateTime.UtcNow : record.TimestampUtc;
            var data = new Dictionary<string, object?>
            {
                ["userId"] = record.UserId,
                ["timestampUtc"] = timestamp,
                ["latitude"] = record.Latitude,
                ["longitude"] = record.Longitude,
                ["status"] = string.IsNullOrWhiteSpace(record.Status) ? "present" : record.Status
            };

            var docRef = await _db.Collection("attendance").AddAsync(data);
            await _hub.Clients.All.SendAsync("attendanceUpdated", record.UserId, new { id = docRef.Id, data });
            created += 1;
        }

        return Ok(new { created });
    }

    [HttpGet("{userId}")]
    public async Task<IActionResult> GetAttendance(string userId)
    {
        if (string.IsNullOrWhiteSpace(userId))
        {
            return BadRequest("UserId required.");
        }

        var query = _db.Collection("attendance")
            .WhereEqualTo("userId", userId)
            .Limit(50);

        var snapshot = await query.GetSnapshotAsync();
        var documents = snapshot.Documents
            .OrderByDescending(doc => doc.TryGetValue("timestampUtc", out Timestamp timestamp)
                ? timestamp.ToDateTime()
                : DateTime.MinValue)
            .ToList();

        var results = documents.Select(doc =>
        {
            var data = doc.ToDictionary();
            if (data.TryGetValue("timestampUtc", out var timestampValue))
            {
                if (timestampValue is Timestamp firestoreTimestamp)
                {
                    data["timestampUtc"] = firestoreTimestamp.ToDateTime().ToUniversalTime().ToString("o");
                }
                else if (timestampValue is DateTime dateTime)
                {
                    data["timestampUtc"] = dateTime.ToUniversalTime().ToString("o");
                }
            }

            return new { id = doc.Id, data };
        });

        return Ok(results);
    }

    [HttpGet("recent")]
    [Authorize(Policy = "Admin")]
    public async Task<IActionResult> GetRecent([FromQuery] int? limit)
    {
        var take = limit is > 0 and <= 200 ? limit.Value : 20;
        var snapshot = await _db.Collection("attendance")
            .OrderByDescending("timestampUtc")
            .Limit(take)
            .GetSnapshotAsync();

        var results = snapshot.Documents.Select(doc =>
        {
            var data = doc.ToDictionary();
            if (data.TryGetValue("timestampUtc", out var timestampValue))
            {
                if (timestampValue is Timestamp firestoreTimestamp)
                {
                    data["timestampUtc"] = firestoreTimestamp.ToDateTime().ToUniversalTime().ToString("o");
                }
                else if (timestampValue is DateTime dateTime)
                {
                    data["timestampUtc"] = dateTime.ToUniversalTime().ToString("o");
                }
            }

            return new { id = doc.Id, data };
        });
        return Ok(results);
    }

    [HttpGet("summary")]
    [Authorize(Policy = "Admin")]
    public async Task<IActionResult> GetSummary([FromQuery] string? date)
    {
        var today = DateTime.UtcNow.Date;
        if (!string.IsNullOrWhiteSpace(date) && DateTime.TryParse(date, out var parsed))
        {
            today = parsed.Date;
        }

        var start = today;
        var end = today.AddDays(1);
        var query = _db.Collection("attendance")
            .WhereGreaterThanOrEqualTo("timestampUtc", start)
            .WhereLessThan("timestampUtc", end);

        var snapshot = await query.GetSnapshotAsync();
        var filtered = snapshot.Documents
            .Where(doc => doc.TryGetValue("status", out string status) &&
                (status == "present" || status == "check_in"))
            .ToList();
        var unique = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        foreach (var doc in filtered)
        {
            if (doc.TryGetValue("userId", out string userId) && !string.IsNullOrWhiteSpace(userId))
            {
                unique.Add(userId);
            }
        }

        return Ok(new { presentToday = unique.Count, totalRecords = snapshot.Count });
    }
}
