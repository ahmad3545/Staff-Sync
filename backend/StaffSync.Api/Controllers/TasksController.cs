using Google.Cloud.Firestore;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using StaffSync.Api.Models;

namespace StaffSync.Api.Controllers;

[ApiController]
[Route("api/tasks")]
[Authorize]
public class TasksController : ControllerBase
{
    private readonly FirestoreDb _db;
    private readonly IWebHostEnvironment _environment;

    public TasksController(FirestoreDb db, IWebHostEnvironment environment)
    {
        _db = db;
        _environment = environment;
    }

    [HttpPost("assign")]
    public async Task<IActionResult> AssignTask([FromBody] TaskAssignRequest request)
    {
        if (string.IsNullOrWhiteSpace(request.UserId) || string.IsNullOrWhiteSpace(request.Title))
        {
            return BadRequest("UserId and Title required.");
        }

        var data = new Dictionary<string, object?>
        {
            ["userId"] = request.UserId,
            ["title"] = request.Title,
            ["description"] = request.Description,
            ["dueDateUtc"] = request.DueDateUtc,
            ["priority"] = request.Priority,
            ["status"] = "assigned",
            ["createdAtUtc"] = DateTime.UtcNow
        };

        var docRef = await _db.Collection("tasks").AddAsync(data);

        // Also add the task id to the user's assignedTasks array so clients
        // that rely on users.{assignedTasks} can pick it up when client-side
        // Firestore writes are not permitted.
        try
        {
            var userRef = _db.Collection("users").Document(request.UserId);
            var updateData = new Dictionary<string, object?>
            {
                ["assignedTasks"] = FieldValue.ArrayUnion(docRef.Id),
                ["updatedAtUtc"] = DateTime.UtcNow
            };
            await userRef.SetAsync(updateData, SetOptions.MergeAll);
        }
        catch
        {
            // Swallow any user update errors to avoid failing the primary operation.
        }

        return Ok(new { id = docRef.Id });
    }

    [HttpGet]
    [Authorize(Policy = "Admin")]
    public async Task<IActionResult> ListAll()
    {
        var query = _db.Collection("tasks")
            .OrderByDescending("createdAtUtc")
            .Limit(200);

        var snapshot = await query.GetSnapshotAsync();
        var results = snapshot.Documents.Select(doc => new { id = doc.Id, data = doc.ToDictionary() });

        return Ok(results);
    }

    [HttpGet("{userId}")]
    public async Task<IActionResult> GetTasks(string userId)
    {
        if (string.IsNullOrWhiteSpace(userId))
        {
            return BadRequest("UserId required.");
        }

        var query = _db.Collection("tasks")
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

    [HttpPost("verify")]
    [Authorize(Policy = "Admin")]
    public async Task<IActionResult> VerifyTask([FromBody] TaskVerifyRequest request)
    {
        if (string.IsNullOrWhiteSpace(request.TaskId))
        {
            return BadRequest("TaskId required.");
        }

        var data = new Dictionary<string, object?>
        {
            ["status"] = request.Status,
            ["reviewerId"] = request.ReviewerId,
            ["notes"] = request.Notes,
            ["updatedAtUtc"] = DateTime.UtcNow
        };

        var docRef = _db.Collection("tasks").Document(request.TaskId);
        await docRef.SetAsync(data, SetOptions.MergeAll);

        return Ok(new { updated = true });
    }

    [HttpPost("{taskId}/proof")]
    public async Task<IActionResult> UploadProof(string taskId, [FromForm] IFormFile file, [FromForm] string? userId, [FromForm] string? remarks)
    {
        if (string.IsNullOrWhiteSpace(taskId))
        {
            return BadRequest("TaskId required.");
        }

        if (file == null || file.Length == 0)
        {
            return BadRequest("File required.");
        }

        var uploadsRoot = Path.Combine(_environment.ContentRootPath, "uploads", "task-proofs");
        Directory.CreateDirectory(uploadsRoot);

        var safeFileName = Path.GetRandomFileName() + Path.GetExtension(file.FileName);
        var filePath = Path.Combine(uploadsRoot, safeFileName);

        await using (var stream = System.IO.File.Create(filePath))
        {
            await file.CopyToAsync(stream);
        }

        var data = new Dictionary<string, object?>
        {
            ["taskId"] = taskId,
            ["userId"] = userId,
            ["fileName"] = file.FileName,
            ["filePath"] = filePath,
            ["remarks"] = remarks,
            ["uploadedAtUtc"] = DateTime.UtcNow
        };

        var docRef = await _db.Collection("taskProofs").AddAsync(data);
        return Ok(new { id = docRef.Id });
    }
}
