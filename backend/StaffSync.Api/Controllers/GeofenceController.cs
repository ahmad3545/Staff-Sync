using Google.Cloud.Firestore;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using StaffSync.Api.Models;

namespace StaffSync.Api.Controllers;

[ApiController]
[Route("api/geofence")]
[Authorize]
public class GeofenceController : ControllerBase
{
    private readonly FirestoreDb _db;

    public GeofenceController(FirestoreDb db)
    {
        _db = db;
    }

    [HttpGet]
    public async Task<IActionResult> GetSettings()
    {
        var docRef = _db.Collection("geofence").Document("default");
        var snapshot = await docRef.GetSnapshotAsync();

        if (!snapshot.Exists)
        {
            return Ok(new { exists = false });
        }

        return Ok(new { exists = true, data = snapshot.ToDictionary() });
    }

    [HttpPost]
    [Authorize(Policy = "Admin")]
    public async Task<IActionResult> UpdateSettings([FromBody] GeofenceSettingsUpdate request)
    {
        var data = new Dictionary<string, object?>
        {
            ["siteName"] = string.IsNullOrWhiteSpace(request.SiteName) ? "Main Office" : request.SiteName,
            ["siteAddress"] = request.SiteAddress,
            ["centerLatitude"] = request.CenterLatitude,
            ["centerLongitude"] = request.CenterLongitude,
            ["radiusMeters"] = request.RadiusMeters,
            ["updatedAtUtc"] = DateTime.UtcNow
        };

        var docRef = _db.Collection("geofence").Document("default");
        await docRef.SetAsync(data);

        return Ok(new { updated = true });
    }
}
