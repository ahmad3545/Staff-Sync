using FirebaseAdmin;
using FirebaseAdmin.Auth;
using Google.Cloud.Firestore;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using StaffSync.Api.Models;

namespace StaffSync.Api.Controllers;

[ApiController]
[Route("api/admin")]
[Authorize(Policy = "Admin")]
public class AdminController : ControllerBase
{
    private const decimal FixedOvertimeRate = 2000m;
    private readonly FirebaseApp _firebaseApp;
    private readonly FirestoreDb _db;
    private readonly IConfiguration _configuration;

    public AdminController(FirebaseApp firebaseApp, FirestoreDb db, IConfiguration configuration)
    {
        _firebaseApp = firebaseApp;
        _db = db;
        _configuration = configuration;
    }

    [AllowAnonymous]
    [HttpPost("bootstrap-admin")]
    public async Task<IActionResult> BootstrapAdmin(
        [FromBody] AdminBootstrapRequest request,
        [FromHeader(Name = "X-Bootstrap-Key")] string? bootstrapKey)
    {
        var enabled = _configuration.GetValue<bool>("AdminBootstrap:Enabled");
        if (!enabled)
        {
            return NotFound();
        }

        var expectedKey = _configuration["AdminBootstrap:Key"];
        if (string.IsNullOrWhiteSpace(expectedKey) || bootstrapKey != expectedKey)
        {
            return Unauthorized();
        }

        if (string.IsNullOrWhiteSpace(request.UserId))
        {
            return BadRequest("UserId required.");
        }

        var auth = FirebaseAuth.GetAuth(_firebaseApp);
        await auth.SetCustomUserClaimsAsync(request.UserId, new Dictionary<string, object>
        {
            ["role"] = "admin"
        });

        var userDoc = _db.Collection("users").Document(request.UserId);
        await userDoc.SetAsync(new Dictionary<string, object>
        {
            ["role"] = "admin",
            ["updatedAtUtc"] = DateTime.UtcNow
        }, SetOptions.MergeAll);

        return Ok(new { updated = true, role = "admin" });
    }

    [HttpPost("roles")]
    public async Task<IActionResult> SetRole([FromBody] AdminRoleUpdateRequest request)
    {
        if (string.IsNullOrWhiteSpace(request.UserId))
        {
            return BadRequest("UserId required.");
        }

        var role = (request.Role ?? "").Trim().ToLowerInvariant();
        var allowed = new HashSet<string> { "admin", "manager", "employee" };
        if (!allowed.Contains(role))
        {
            return BadRequest("Role must be admin, manager, or employee.");
        }

        var auth = FirebaseAuth.GetAuth(_firebaseApp);
        await auth.SetCustomUserClaimsAsync(request.UserId, new Dictionary<string, object>
        {
            ["role"] = role
        });

        var userDoc = _db.Collection("users").Document(request.UserId);
        await userDoc.SetAsync(new Dictionary<string, object>
        {
            ["role"] = role,
            ["updatedAtUtc"] = DateTime.UtcNow
        }, SetOptions.MergeAll);

        return Ok(new { updated = true, role });
    }

    [HttpPost("users")]
    public async Task<IActionResult> CreateUser([FromBody] AdminUserCreateRequest request)
    {
        if (string.IsNullOrWhiteSpace(request.Email) || string.IsNullOrWhiteSpace(request.Password))
        {
            return BadRequest("Email and Password required.");
        }

        var role = (request.Role ?? "employee").Trim().ToLowerInvariant();
        var allowed = new HashSet<string> { "admin", "manager", "employee" };
        if (!allowed.Contains(role))
        {
            return BadRequest("Role must be admin, manager, or employee.");
        }

        var auth = FirebaseAuth.GetAuth(_firebaseApp);
        var args = new UserRecordArgs
        {
            Email = request.Email.Trim(),
            Password = request.Password,
            DisplayName = string.IsNullOrWhiteSpace(request.FullName)
                ? request.Email.Trim()
                : request.FullName.Trim()
        };

        var user = await auth.CreateUserAsync(args);
        await auth.SetCustomUserClaimsAsync(user.Uid, new Dictionary<string, object>
        {
            ["role"] = role
        });

        var data = new Dictionary<string, object?>
        {
            ["fullName"] = request.FullName,
            ["departmentId"] = request.DepartmentId,
            ["role"] = role,
            ["phone"] = request.Phone,
            ["email"] = request.Email.Trim(),
            ["createdAtUtc"] = DateTime.UtcNow,
            ["updatedAtUtc"] = DateTime.UtcNow
        };

        var docRef = _db.Collection("users").Document(user.Uid);
        await docRef.SetAsync(data, SetOptions.MergeAll);

        return Ok(new { id = user.Uid, role });
    }

    [HttpPost("payroll-settings")]
    public async Task<IActionResult> SetPayrollSettings([FromBody] PayrollSettingsUpdateRequest request)
    {
        if (string.IsNullOrWhiteSpace(request.UserId))
        {
            return BadRequest("UserId required.");
        }

        if (request.BaseSalary < 0)
        {
            return BadRequest("Base salary must be zero or greater.");
        }

        try
        {
            var userDoc = _db.Collection("users").Document(request.UserId);
            await userDoc.SetAsync(new Dictionary<string, object>
            {
                ["baseSalary"] = Convert.ToDouble(request.BaseSalary),
                ["overtimeRate"] = Convert.ToDouble(FixedOvertimeRate),
                ["updatedAtUtc"] = DateTime.UtcNow
            }, SetOptions.MergeAll);

            return Ok(new
            {
                updated = true,
                baseSalary = request.BaseSalary,
                overtimeRate = FixedOvertimeRate
            });
        }
        catch (Exception ex)
        {
            Console.Error.WriteLine(ex);
            return StatusCode(500, new { message = "Failed to save payroll settings." });
        }
    }
}
