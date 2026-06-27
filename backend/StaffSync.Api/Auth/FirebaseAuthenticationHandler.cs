using System.Security.Claims;
using System.Text.Encodings.Web;
using FirebaseAdmin;
using FirebaseAdmin.Auth;
using Microsoft.AspNetCore.Authentication;
using Microsoft.Extensions.Options;

namespace StaffSync.Api.Auth;

public sealed class FirebaseAuthenticationHandler : AuthenticationHandler<AuthenticationSchemeOptions>
{
    private readonly FirebaseApp _firebaseApp;

    public FirebaseAuthenticationHandler(
        IOptionsMonitor<AuthenticationSchemeOptions> options,
        ILoggerFactory logger,
        UrlEncoder encoder,
        FirebaseApp firebaseApp)
        : base(options, logger, encoder)
    {
        _firebaseApp = firebaseApp;
    }

    protected override async Task<AuthenticateResult> HandleAuthenticateAsync()
    {
        if (!Request.Headers.TryGetValue("Authorization", out var authHeader))
        {
            return AuthenticateResult.NoResult();
        }

        var header = authHeader.ToString();
        if (!header.StartsWith("Bearer ", StringComparison.OrdinalIgnoreCase))
        {
            return AuthenticateResult.NoResult();
        }

        var token = header.Substring("Bearer ".Length).Trim();
        if (string.IsNullOrWhiteSpace(token))
        {
            return AuthenticateResult.NoResult();
        }

        try
        {
            var auth = FirebaseAuth.GetAuth(_firebaseApp);
            var decoded = await auth.VerifyIdTokenAsync(token);
            var claims = new List<Claim>
            {
                new Claim(ClaimTypes.NameIdentifier, decoded.Uid)
            };

            if (decoded.Claims.TryGetValue("email", out var emailValue) && emailValue != null)
            {
                claims.Add(new Claim(ClaimTypes.Email, emailValue.ToString()!));
            }

            foreach (var pair in decoded.Claims)
            {
                if (pair.Value == null)
                {
                    continue;
                }

                var value = pair.Value.ToString();
                if (string.IsNullOrWhiteSpace(value))
                {
                    continue;
                }

                claims.Add(new Claim(pair.Key, value));
            }

            var identity = new ClaimsIdentity(claims, Scheme.Name);
            var principal = new ClaimsPrincipal(identity);
            var ticket = new AuthenticationTicket(principal, Scheme.Name);

            return AuthenticateResult.Success(ticket);
        }
        catch (Exception ex)
        {
            Logger.LogWarning(ex, "Firebase token validation failed.");
            return AuthenticateResult.Fail("Invalid Firebase token.");
        }
    }
}
