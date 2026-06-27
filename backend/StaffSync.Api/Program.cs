using FirebaseAdmin;
using Google.Apis.Auth.OAuth2;
using Google.Cloud.Firestore;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.HttpLogging;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Options;
using StaffSync.Api.Auth;
using StaffSync.Api.Hubs;
using StaffSync.Api.Options;
using StaffSync.Api.Services;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddOpenApi();
builder.Services.AddControllers().ConfigureApiBehaviorOptions(options =>
{
    options.InvalidModelStateResponseFactory = context =>
    {
        var problemDetails = new ValidationProblemDetails(context.ModelState)
        {
            Status = StatusCodes.Status400BadRequest,
            Title = "Validation failed.",
            Type = "https://httpstatuses.com/400"
        };

        return new BadRequestObjectResult(problemDetails);
    };
});
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();
builder.Services.AddSignalR();
builder.Services.AddCors(options =>
{
    options.AddPolicy("DevCors", policy =>
        policy.AllowAnyOrigin().AllowAnyHeader().AllowAnyMethod());
});
builder.Services.AddHttpLogging(options =>
{
    options.LoggingFields = HttpLoggingFields.RequestMethod
        | HttpLoggingFields.RequestPath
        | HttpLoggingFields.ResponseStatusCode;
});
builder.Services.AddProblemDetails();
builder.Services.AddSingleton<PerformancePredictionService>();
builder.Services.AddSingleton<PayrollService>();
builder.Services.AddSingleton<PayrollPdfBuilder>();
builder.Services.AddSingleton<TranslationService>();
builder.Services.AddSingleton<TextToSpeechService>();
builder.Services.AddSingleton<ExportService>();

builder.Services.Configure<FirebaseOptions>(builder.Configuration.GetSection("Firebase"));
builder.Services.Configure<MlOptions>(builder.Configuration.GetSection("Ml"));

builder.Services.AddSingleton(provider =>
{
    var options = provider.GetRequiredService<IOptions<FirebaseOptions>>().Value;
    if (string.IsNullOrWhiteSpace(options.ProjectId))
    {
        throw new InvalidOperationException("Firebase ProjectId is required.");
    }
    var credential = string.IsNullOrWhiteSpace(options.CredentialPath)
        ? GoogleCredential.GetApplicationDefault()
        : GoogleCredential.FromFile(options.CredentialPath);

    var appOptions = new AppOptions
    {
        Credential = credential,
        ProjectId = options.ProjectId
    };

    FirebaseApp? existing = null;
    try
    {
        existing = FirebaseApp.DefaultInstance;
    }
    catch (Exception)
    {
        // Default instance not created yet.
    }

    return existing ?? FirebaseApp.Create(appOptions);
});

builder.Services.AddSingleton(provider =>
{
    var options = provider.GetRequiredService<IOptions<FirebaseOptions>>().Value;
    if (string.IsNullOrWhiteSpace(options.ProjectId))
    {
        throw new InvalidOperationException("Firebase ProjectId is required.");
    }
    var credential = string.IsNullOrWhiteSpace(options.CredentialPath)
        ? GoogleCredential.GetApplicationDefault()
        : GoogleCredential.FromFile(options.CredentialPath);

    var dbBuilder = new FirestoreDbBuilder
    {
        ProjectId = options.ProjectId,
        Credential = credential
    };

    return dbBuilder.Build();
});

builder.Services.AddAuthentication(options =>
{
    options.DefaultAuthenticateScheme = "Firebase";
    options.DefaultChallengeScheme = "Firebase";
}).AddScheme<AuthenticationSchemeOptions, FirebaseAuthenticationHandler>("Firebase", _ => { });

builder.Services.AddAuthorization(options =>
{
    options.AddPolicy("Admin", policy => policy.RequireClaim("role", "admin"));
});

var app = builder.Build();

if (app.Environment.IsDevelopment())
{
    app.MapOpenApi();
    app.UseSwagger();
    app.UseSwaggerUI();
}
else
{
    app.UseExceptionHandler("/error");
    app.UseHsts();
    app.UseHttpsRedirection();
}

app.UseHttpLogging();

app.UseCors("DevCors");

app.UseAuthentication();
app.UseAuthorization();

app.MapControllers();
app.MapHub<AttendanceHub>("/hubs/attendance");
app.Map("/error", () => Results.Problem("An unexpected error occurred.", statusCode: StatusCodes.Status500InternalServerError));

app.MapGet("/", () => Results.Ok(new { service = "StaffSync.Api", status = "running" }));

app.Run();

public partial class Program
{
}
