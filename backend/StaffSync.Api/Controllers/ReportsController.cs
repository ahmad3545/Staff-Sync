using System.Security.Claims;
using Google.Cloud.Firestore;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using StaffSync.Api.Models;

namespace StaffSync.Api.Controllers;

[ApiController]
[Route("api/reports")]
[Authorize]
public class ReportsController : ControllerBase
{
    private readonly FirestoreDb _db;

    public ReportsController(FirestoreDb db)
    {
        _db = db;
    }

    [HttpPost("generate")]
    public async Task<IActionResult> GenerateReport([FromBody] ReportRequest request)
    {
        if (string.IsNullOrWhiteSpace(request.UserId))
        {
            return BadRequest("UserId required.");
        }

        var currentUserId = User.FindFirstValue(ClaimTypes.NameIdentifier);
        if (string.IsNullOrWhiteSpace(currentUserId))
        {
            return Unauthorized();
        }

        var isAdmin = User.Claims.Any(c => c.Type == "role" && c.Value == "admin");
        if (!isAdmin && request.UserId != currentUserId)
        {
            return Forbid();
        }

        var data = new Dictionary<string, object?>
        {
            ["userId"] = request.UserId,
            ["fromUtc"] = request.FromUtc,
            ["toUtc"] = request.ToUtc,
            ["type"] = request.Type,
            ["status"] = "generated",
            ["createdAtUtc"] = DateTime.UtcNow,
            ["generatedAtUtc"] = DateTime.UtcNow
        };

        var docRef = await _db.Collection("reports").AddAsync(data);
        return Ok(new { id = docRef.Id, status = "generated" });
    }

    [HttpPost("generate/dev")]
    [AllowAnonymous]
    public async Task<IActionResult> GenerateReportDev([FromBody] ReportRequest request)
    {
        if (request == null || string.IsNullOrWhiteSpace(request.UserId))
        {
            return BadRequest("UserId required.");
        }

        var data = new Dictionary<string, object?>
        {
            ["userId"] = request.UserId,
            ["fromUtc"] = request.FromUtc,
            ["toUtc"] = request.ToUtc,
            ["type"] = request.Type,
            ["status"] = "generated",
            ["createdAtUtc"] = DateTime.UtcNow,
            ["generatedAtUtc"] = DateTime.UtcNow,
        };

        var docRef = await _db.Collection("reports").AddAsync(data);
        return Ok(new { id = docRef.Id, status = "generated" });
    }

    [HttpGet]
    public async Task<IActionResult> ListAll()
    {
        var currentUserId = User.FindFirstValue(ClaimTypes.NameIdentifier);
        if (string.IsNullOrWhiteSpace(currentUserId))
        {
            return Unauthorized();
        }

        var isAdmin = User.Claims.Any(c => c.Type == "role" && c.Value == "admin");
        var snapshot = await _db.Collection("reports").Limit(300).GetSnapshotAsync();
        var results = snapshot.Documents
            .Select(doc =>
            {
                var data = doc.ToDictionary();
                NormalizeDate(data, "fromUtc");
                NormalizeDate(data, "toUtc");
                NormalizeDate(data, "createdAtUtc");
                NormalizeDate(data, "generatedAtUtc");

                return new { id = doc.Id, data };
            })
            .Where(item => isAdmin ||
                (item.data.TryGetValue("userId", out var userId) &&
                    string.Equals(userId?.ToString(), currentUserId, StringComparison.OrdinalIgnoreCase)))
            .OrderByDescending(item => ParseDate(item.data.TryGetValue("createdAtUtc", out var created) ? created : null) ?? DateTime.MinValue)
            .Take(100);
        return Ok(results);
    }

    private static void NormalizeDate(Dictionary<string, object> data, string key)
    {
        if (!data.TryGetValue(key, out var value))
        {
            return;
        }

        if (value is Timestamp timestamp)
        {
            data[key] = timestamp.ToDateTime().ToUniversalTime().ToString("o");
        }
        else if (value is DateTime dateTime)
        {
            data[key] = dateTime.ToUniversalTime().ToString("o");
        }
    }

    private static DateTime? ParseDate(object? value)
    {
        return value switch
        {
            Timestamp timestamp => timestamp.ToDateTime().ToUniversalTime(),
            DateTime dateTime => dateTime.ToUniversalTime(),
            string text when DateTime.TryParse(text, out var parsed) => parsed.ToUniversalTime(),
            _ => null
        };
    }
}
