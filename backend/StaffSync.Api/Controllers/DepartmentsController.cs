using Google.Cloud.Firestore;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using StaffSync.Api.Models;

namespace StaffSync.Api.Controllers;

[ApiController]
[Route("api/departments")]
[Authorize]
public class DepartmentsController : ControllerBase
{
    private readonly FirestoreDb _db;

    public DepartmentsController(FirestoreDb db)
    {
        _db = db;
    }

    [HttpPost]
    [Authorize(Policy = "Admin")]
    public async Task<IActionResult> Create([FromBody] DepartmentCreate request)
    {
        if (string.IsNullOrWhiteSpace(request.Name))
        {
            return BadRequest("Name required.");
        }

        var data = new Dictionary<string, object?>
        {
            ["name"] = request.Name,
            ["description"] = request.Description,
            ["createdAtUtc"] = DateTime.UtcNow
        };

        var docRef = await _db.Collection("departments").AddAsync(data);
        return Ok(new { id = docRef.Id });
    }

    [HttpGet]
    public async Task<IActionResult> List()
    {
        var snapshot = await _db.Collection("departments").OrderBy("name").GetSnapshotAsync();
        var results = snapshot.Documents.Select(doc => new { id = doc.Id, data = doc.ToDictionary() });

        return Ok(results);
    }
}
