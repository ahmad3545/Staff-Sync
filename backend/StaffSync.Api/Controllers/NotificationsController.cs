using Google.Cloud.Firestore;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using StaffSync.Api.Models;

namespace StaffSync.Api.Controllers;

[ApiController]
[Route("api/notifications")]
[Authorize]
public class NotificationsController : ControllerBase
{
    private readonly FirestoreDb _db;

    public NotificationsController(FirestoreDb db)
    {
        _db = db;
    }

    [HttpPost("send")]
    [Authorize(Policy = "Admin")]
    public async Task<IActionResult> Send([FromBody] NotificationSendRequest request)
    {
        if (string.IsNullOrWhiteSpace(request.UserId) || string.IsNullOrWhiteSpace(request.Title))
        {
            return BadRequest("UserId and Title required.");
        }

        var data = new Dictionary<string, object?>
        {
            ["userId"] = request.UserId,
            ["title"] = request.Title,
            ["body"] = request.Body,
            ["type"] = request.Type,
            ["createdAtUtc"] = DateTime.UtcNow
        };

        var docRef = await _db.Collection("notifications").AddAsync(data);
        return Ok(new { id = docRef.Id });
    }

    [HttpPost("broadcast")]
    [Authorize(Policy = "Admin")]
    public async Task<IActionResult> Broadcast([FromBody] NotificationBroadcastRequest request)
    {
        if (string.IsNullOrWhiteSpace(request.Title))
        {
            return BadRequest("Title required.");
        }

        // Get all non-admin users from users collection
        var usersSnapshot = await _db.Collection("users").GetSnapshotAsync();
        var userIds = usersSnapshot.Documents
            .Where(doc => !doc.TryGetValue("role", out string? role) || !string.Equals(role, "admin", StringComparison.OrdinalIgnoreCase))
            .Select(doc => doc.Id)
            .ToList();

        if (!userIds.Any())
        {
            return BadRequest("No users found.");
        }

        var tasks = new List<Task>();
        foreach (var userId in userIds)
        {
            var data = new Dictionary<string, object?>
            {
                ["userId"] = userId,
                ["title"] = request.Title,
                ["body"] = request.Body ?? "",
                ["type"] = request.Type ?? "info",
                ["createdAtUtc"] = DateTime.UtcNow
            };

            tasks.Add(_db.Collection("notifications").AddAsync(data));
        }

        await Task.WhenAll(tasks);
        return Ok(new { sent = userIds.Count, message = $"Notification sent to {userIds.Count} users" });
    }

    [HttpGet("{userId}")]
    public async Task<IActionResult> GetNotifications(string userId)
    {
        if (string.IsNullOrWhiteSpace(userId))
        {
            return BadRequest("UserId required.");
        }

        var query = _db.Collection("notifications")
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
}
