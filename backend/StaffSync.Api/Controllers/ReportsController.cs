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
        var query = _db.Collection("reports").OrderByDescending("createdAtUtc").Limit(100);
        if (!isAdmin)
        {
            query = query.WhereEqualTo("userId", currentUserId);
        }

        var snapshot = await query.GetSnapshotAsync();
        var results = snapshot.Documents.Select(doc => new { id = doc.Id, data = doc.ToDictionary() });
        return Ok(results);
    }
}
