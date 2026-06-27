using Google.Cloud.Firestore;
using Microsoft.AspNetCore.Mvc;

namespace StaffSync.Api.Controllers;

[ApiController]
[Route("api/debug")]
public class DebugController : ControllerBase
{
    private readonly FirestoreDb _db;

    public DebugController(FirestoreDb db)
    {
        _db = db;
    }

    [HttpGet("users")]
    public async Task<IActionResult> ListUsers()
    {
        var snapshot = await _db.Collection("users").Limit(200).GetSnapshotAsync();
        var results = snapshot.Documents.Select(d => new { id = d.Id, data = d.ToDictionary() });
        return Ok(results);
    }

    [HttpGet("user/{id}")]
    public async Task<IActionResult> GetUser(string id)
    {
        if (string.IsNullOrWhiteSpace(id)) return BadRequest("id required");
        var snap = await _db.Collection("users").Document(id).GetSnapshotAsync();
        if (!snap.Exists) return NotFound();
        return Ok(new { id = snap.Id, data = snap.ToDictionary() });
    }

    [HttpGet("tasks")]
    public async Task<IActionResult> ListTasks()
    {
        var snapshot = await _db.Collection("tasks").OrderByDescending("createdAtUtc").Limit(200).GetSnapshotAsync();
        var results = snapshot.Documents.Select(d => new { id = d.Id, data = d.ToDictionary() });
        return Ok(results);
    }

    [HttpGet("tasks/user/{id}")]
    public async Task<IActionResult> GetTasksForUser(string id)
    {
        if (string.IsNullOrWhiteSpace(id)) return BadRequest("id required");
        var query = _db.Collection("tasks").WhereEqualTo("userId", id).OrderByDescending("createdAtUtc").Limit(200);
        var snapshot = await query.GetSnapshotAsync();
        var results = snapshot.Documents.Select(d => new { id = d.Id, data = d.ToDictionary() });
        return Ok(results);
    }

    [HttpPost("sync-assigned-tasks")]
    public async Task<IActionResult> SyncAssignedTasks()
    {
        var snapshot = await _db.Collection("tasks").GetSnapshotAsync();
        var byUser = snapshot.Documents
            .Where(d => d.Exists)
            .GroupBy(d => d.GetValue<string>("userId") ?? "")
            .Where(g => !string.IsNullOrWhiteSpace(g.Key));

        foreach (var group in byUser)
        {
            var userId = group.Key;
            var ids = group.Select(d => d.Id).ToArray();
            try
            {
                var userRef = _db.Collection("users").Document(userId);
                // Use ArrayUnion to avoid duplicates
                await userRef.SetAsync(new Dictionary<string, object?>
                {
                    ["assignedTasks"] = FieldValue.ArrayUnion(ids.Cast<object>().ToArray()),
                    ["updatedAtUtc"] = DateTime.UtcNow
                }, SetOptions.MergeAll);
            }
            catch
            {
                // ignore per-user failures
            }
        }

        return Ok(new { synced = true });
    }
}
