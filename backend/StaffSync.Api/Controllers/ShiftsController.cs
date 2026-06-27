using Google.Cloud.Firestore;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using StaffSync.Api.Models;

namespace StaffSync.Api.Controllers;

[ApiController]
[Route("api/shifts")]
[Authorize]
public class ShiftsController : ControllerBase
{
    private readonly FirestoreDb _db;

    public ShiftsController(FirestoreDb db)
    {
        _db = db;
    }

    [HttpPost]
    [Authorize(Policy = "Admin")]
    public async Task<IActionResult> Create([FromBody] ShiftCreateRequest request)
    {
        if (request.EndTimeUtc <= request.StartTimeUtc)
        {
            return BadRequest("End time must be after start time.");
        }

        var data = new Dictionary<string, object?>
        {
            ["name"] = request.Name,
            ["startTimeUtc"] = request.StartTimeUtc,
            ["endTimeUtc"] = request.EndTimeUtc,
            ["location"] = request.Location,
            ["status"] = request.Status,
            ["assignedUserIds"] = Array.Empty<string>(),
            ["createdAtUtc"] = DateTime.UtcNow
        };

        var docRef = await _db.Collection("shifts").AddAsync(data);
        return Ok(new { id = docRef.Id });
    }

    [HttpGet]
    public async Task<IActionResult> List()
    {
        var snapshot = await _db.Collection("shifts").OrderByDescending("createdAtUtc").Limit(100).GetSnapshotAsync();
        var results = snapshot.Documents.Select(doc => new { id = doc.Id, data = doc.ToDictionary() });
        return Ok(results);
    }

    [HttpPut]
    [Authorize(Policy = "Admin")]
    public async Task<IActionResult> Update([FromBody] ShiftUpdateRequest request)
    {
        if (string.IsNullOrWhiteSpace(request.ShiftId))
        {
            return BadRequest("ShiftId required.");
        }

        var data = new Dictionary<string, object?>
        {
            ["name"] = request.Name,
            ["startTimeUtc"] = request.StartTimeUtc,
            ["endTimeUtc"] = request.EndTimeUtc,
            ["location"] = request.Location,
            ["status"] = request.Status,
            ["updatedAtUtc"] = DateTime.UtcNow
        };

        var docRef = _db.Collection("shifts").Document(request.ShiftId);
        await docRef.SetAsync(data, SetOptions.MergeAll);

        return Ok(new { updated = true });
    }

    [HttpPost("assign")]
    [Authorize(Policy = "Admin")]
    public async Task<IActionResult> Assign([FromBody] ShiftAssignRequest request)
    {
        if (string.IsNullOrWhiteSpace(request.ShiftId))
        {
            return BadRequest("ShiftId required.");
        }

        var docRef = _db.Collection("shifts").Document(request.ShiftId);
        var snapshot = await docRef.GetSnapshotAsync();
        if (!snapshot.Exists)
        {
            return NotFound();
        }

        var data = new Dictionary<string, object?>
        {
            ["assignedUserIds"] = request.UserIds,
            ["updatedAtUtc"] = DateTime.UtcNow
        };

        await docRef.SetAsync(data, SetOptions.MergeAll);
        return Ok(new { updated = true });
    }

    [HttpDelete("{shiftId}")]
    [Authorize(Policy = "Admin")]
    public async Task<IActionResult> Delete(string shiftId)
    {
        if (string.IsNullOrWhiteSpace(shiftId))
        {
            return BadRequest("ShiftId required.");
        }

        await _db.Collection("shifts").Document(shiftId).DeleteAsync();
        return Ok(new { deleted = true });
    }
}
