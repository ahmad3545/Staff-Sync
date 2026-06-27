using FirebaseAdmin.Auth;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using StaffSync.Api.Models;

namespace StaffSync.Api.Controllers;

[ApiController]
[Route("api/auth")]
public class AuthController : ControllerBase
{
    [HttpPost("verify")]
    [AllowAnonymous]
    public async Task<IActionResult> Verify([FromBody] VerifyTokenRequest request)
    {
        if (string.IsNullOrWhiteSpace(request.IdToken))
        {
            return BadRequest("IdToken required.");
        }

        var decoded = await FirebaseAuth.DefaultInstance.VerifyIdTokenAsync(request.IdToken);
        var response = new Dictionary<string, object?>
        {
            ["uid"] = decoded.Uid,
            ["claims"] = decoded.Claims
        };

        if (decoded.Claims.TryGetValue("email", out var emailValue))
        {
            response["email"] = emailValue?.ToString();
        }

        return Ok(response);
    }
}
