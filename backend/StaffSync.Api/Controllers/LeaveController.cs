using Google.Cloud.Firestore;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using StaffSync.Api.Models;

namespace StaffSync.Api.Controllers;

[ApiController]
[Route("api/leave")]
[Authorize]
public class LeaveController : ControllerBase
{
    private readonly FirestoreDb _db;

    public LeaveController(FirestoreDb db)
    {
        _db = db;
    }

    [HttpGet]
    [Authorize(Policy = "Admin")]
    public async Task<IActionResult> ListAll()
    {
        var query = _db.Collection("leaveRequests")
            .OrderByDescending("createdAtUtc")
            .Limit(200);

        var snapshot = await query.GetSnapshotAsync();
        var results = snapshot.Documents.Select(doc => new { id = doc.Id, data = doc.ToDictionary() });

        return Ok(results);
    }

    [HttpPost("request")]
    public async Task<IActionResult> RequestLeave([FromBody] LeaveRequestCreate request)
    {
        if (string.IsNullOrWhiteSpace(request.UserId))
        {
            return BadRequest("UserId required.");
        }

        var data = new Dictionary<string, object?>
        {
            ["userId"] = request.UserId,
            ["startDateUtc"] = request.StartDateUtc,
            ["endDateUtc"] = request.EndDateUtc,
            ["reason"] = request.Reason,
            ["status"] = "pending",
            ["createdAtUtc"] = DateTime.UtcNow
        };

        var docRef = await _db.Collection("leaveRequests").AddAsync(data);
        return Ok(new { id = docRef.Id });
    }

    [HttpGet("{userId}")]
    public async Task<IActionResult> GetLeaveRequests(string userId)
    {
        if (string.IsNullOrWhiteSpace(userId))
        {
            return BadRequest("UserId required.");
        }

        var query = _db.Collection("leaveRequests")
            .WhereEqualTo("userId", userId)
            .Limit(50);

        var snapshot = await query.GetSnapshotAsync();
        var documents = snapshot.Documents
            .OrderByDescending(doc => doc.TryGetValue("createdAtUtc", out Timestamp timestamp)
                ? timestamp.ToDateTime()
                : DateTime.MinValue)
            .ToList();
        var results = documents.Select(doc => new { id = doc.Id, data = doc.ToDictionary() });

        return Ok(results);
    }

    [HttpPost("approve")]
    [Authorize(Policy = "Admin")]
    public async Task<IActionResult> ApproveLeave([FromBody] LeaveApproveRequest request)
    {
        if (string.IsNullOrWhiteSpace(request.LeaveId))
        {
            return BadRequest("LeaveId required.");
        }

        var leaveDoc = await _db.Collection("leaveRequests").Document(request.LeaveId).GetSnapshotAsync();
        if (!leaveDoc.Exists)
        {
            return NotFound("Leave request not found.");
        }

        var leaveData = leaveDoc.ToDictionary();
        var userId = leaveData.TryGetValue("userId", out var rawUserId)
            ? rawUserId?.ToString()
            : null;

        var data = new Dictionary<string, object?>
        {
            ["status"] = request.Status,
            ["approverId"] = request.ApproverId,
            ["notes"] = request.Notes,
            ["updatedAtUtc"] = DateTime.UtcNow
        };

        var docRef = _db.Collection("leaveRequests").Document(request.LeaveId);
        await docRef.SetAsync(data, SetOptions.MergeAll);

        if (!string.IsNullOrWhiteSpace(userId))
        {
            var statusLabel = request.Status?.ToLowerInvariant() switch
            {
                "approved" => "Approved",
                "rejected" => "Rejected",
                _ => "Updated"
            };
            var notification = new Dictionary<string, object?>
            {
                ["userId"] = userId,
                ["title"] = "Leave request updated",
                ["body"] = $"Your leave request was {statusLabel.ToLowerInvariant()}.",
                ["type"] = request.Status?.ToLowerInvariant() == "approved"
                    ? "success"
                    : "warning",
                ["createdAtUtc"] = DateTime.UtcNow
            };
            await _db.Collection("notifications").AddAsync(notification);
        }

        return Ok(new { updated = true });
    }
}
