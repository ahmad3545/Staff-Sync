using FirebaseAdmin;
using FirebaseAdmin.Auth;
using Google.Cloud.Firestore;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using StaffSync.Api.Models;

namespace StaffSync.Api.Controllers;

[ApiController]
[Route("api/users")]
[Authorize]
public class UsersController : ControllerBase
{
    private readonly FirestoreDb _db;
    private readonly FirebaseApp _firebaseApp;

    public UsersController(FirestoreDb db, FirebaseApp firebaseApp)
    {
        _db = db;
        _firebaseApp = firebaseApp;
    }

    [HttpGet]
    [Authorize(Policy = "Admin")]
    public async Task<IActionResult> List()
    {
        var snapshot = await _db.Collection("users")
            .OrderBy("updatedAtUtc")
            .Limit(200)
            .GetSnapshotAsync();
        var auth = FirebaseAuth.GetAuth(_firebaseApp);
        var results = new List<object>();

        foreach (var doc in snapshot.Documents)
        {
            var data = doc.ToDictionary();
            var fullName = data.TryGetValue("fullName", out var rawName)
                ? rawName?.ToString()
                : null;
            var email = data.TryGetValue("email", out var rawEmail)
                ? rawEmail?.ToString()
                : null;

            if (string.IsNullOrWhiteSpace(fullName) || string.IsNullOrWhiteSpace(email))
            {
                try
                {
                    var user = await auth.GetUserAsync(doc.Id);
                    var fallbackName = string.IsNullOrWhiteSpace(user.DisplayName)
                        ? user.Email
                        : user.DisplayName;
                    if (string.IsNullOrWhiteSpace(fullName) && !string.IsNullOrWhiteSpace(fallbackName))
                    {
                        data["fullName"] = fallbackName;
                        fullName = fallbackName;
                    }
                    if (string.IsNullOrWhiteSpace(email) && !string.IsNullOrWhiteSpace(user.Email))
                    {
                        data["email"] = user.Email;
                        email = user.Email;
                    }

                    if (!string.IsNullOrWhiteSpace(fullName) || !string.IsNullOrWhiteSpace(email))
                    {
                        await doc.Reference.SetAsync(new Dictionary<string, object?>
                        {
                            ["fullName"] = fullName,
                            ["email"] = email,
                            ["updatedAtUtc"] = DateTime.UtcNow
                        }, SetOptions.MergeAll);
                    }
                }
                catch
                {
                    // Ignore lookup failures.
                }
            }

            results.Add(new { id = doc.Id, data });
        }

        return Ok(results);
    }

    [HttpGet("{userId}")]
    public async Task<IActionResult> GetUser(string userId)
    {
        if (string.IsNullOrWhiteSpace(userId))
        {
            return BadRequest("UserId required.");
        }

        var snapshot = await _db.Collection("users").Document(userId).GetSnapshotAsync();
        if (!snapshot.Exists)
        {
            return NotFound();
        }

        var data = snapshot.ToDictionary();
        var fullName = data.TryGetValue("fullName", out var rawName)
            ? rawName?.ToString()
            : null;
        var email = data.TryGetValue("email", out var rawEmail)
            ? rawEmail?.ToString()
            : null;

        if (string.IsNullOrWhiteSpace(fullName) || string.IsNullOrWhiteSpace(email))
        {
            try
            {
                var auth = FirebaseAuth.GetAuth(_firebaseApp);
                var user = await auth.GetUserAsync(userId);
                var fallbackName = string.IsNullOrWhiteSpace(user.DisplayName)
                    ? user.Email
                    : user.DisplayName;
                if (string.IsNullOrWhiteSpace(fullName) && !string.IsNullOrWhiteSpace(fallbackName))
                {
                    data["fullName"] = fallbackName;
                    fullName = fallbackName;
                }
                if (string.IsNullOrWhiteSpace(email) && !string.IsNullOrWhiteSpace(user.Email))
                {
                    data["email"] = user.Email;
                    email = user.Email;
                }

                if (!string.IsNullOrWhiteSpace(fullName) || !string.IsNullOrWhiteSpace(email))
                {
                    await snapshot.Reference.SetAsync(new Dictionary<string, object?>
                    {
                        ["fullName"] = fullName,
                        ["email"] = email,
                        ["updatedAtUtc"] = DateTime.UtcNow
                    }, SetOptions.MergeAll);
                }
            }
            catch
            {
                // Ignore lookup failures.
            }
        }

        return Ok(new { id = snapshot.Id, data });
    }

    [HttpPost("profile")]
    public async Task<IActionResult> UpdateProfile([FromBody] UserProfileUpdate request)
    {
        if (string.IsNullOrWhiteSpace(request.UserId))
        {
            return BadRequest("UserId required.");
        }

        var data = new Dictionary<string, object?>
        {
            ["fullName"] = request.FullName,
            ["departmentId"] = request.DepartmentId,
            ["role"] = request.Role,
            ["phone"] = request.Phone,
            ["email"] = request.Email,
            ["updatedAtUtc"] = DateTime.UtcNow
        };

        var docRef = _db.Collection("users").Document(request.UserId);
        await docRef.SetAsync(data, SetOptions.MergeAll);

        return Ok(new { updated = true });
    }

    [HttpDelete("{userId}")]
    [Authorize(Policy = "Admin")]
    public async Task<IActionResult> DeleteUser(string userId)
    {
        if (string.IsNullOrWhiteSpace(userId))
        {
            return BadRequest("UserId required.");
        }

        var docRef = _db.Collection("users").Document(userId);
        await docRef.DeleteAsync();

        try
        {
            var auth = FirebaseAuth.GetAuth(_firebaseApp);
            await auth.DeleteUserAsync(userId);
        }
        catch
        {
            // Ignore failures if auth user cannot be deleted.
        }

        return Ok(new { deleted = true });
    }
}
