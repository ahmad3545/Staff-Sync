using System.Security.Claims;
using Google.Cloud.Firestore;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using StaffSync.Api.Services;

namespace StaffSync.Api.Controllers;

[ApiController]
[Route("api/exports")]
[Authorize]
public class ExportsController : ControllerBase
{
    private readonly FirestoreDb _db;
    private readonly ExportService _exportService;

    public ExportsController(FirestoreDb db, ExportService exportService)
    {
        _db = db;
        _exportService = exportService;
    }

    [HttpGet("attendance")]
    public Task<IActionResult> ExportAttendance([FromQuery] string? userId, [FromQuery] DateTime? fromUtc, [FromQuery] DateTime? toUtc, [FromQuery] string format = "csv")
    {
        if (!IsAuthorizedForUser(userId))
        {
            return Task.FromResult((IActionResult)Forbid());
        }
        return ExportCollection("attendance", "timestampUtc", "Attendance Export", userId, fromUtc, toUtc, format);
    }

    [HttpGet("leaves")]
    public Task<IActionResult> ExportLeaves([FromQuery] string? userId, [FromQuery] DateTime? fromUtc, [FromQuery] DateTime? toUtc, [FromQuery] string format = "csv")
    {
        if (!IsAuthorizedForUser(userId))
        {
            return Task.FromResult((IActionResult)Forbid());
        }
        return ExportCollection("leaveRequests", "createdAtUtc", "Leave Export", userId, fromUtc, toUtc, format);
    }

    [HttpGet("tasks")]
    public Task<IActionResult> ExportTasks([FromQuery] string? userId, [FromQuery] DateTime? fromUtc, [FromQuery] DateTime? toUtc, [FromQuery] string format = "csv")
    {
        if (!IsAuthorizedForUser(userId))
        {
            return Task.FromResult((IActionResult)Forbid());
        }
        return ExportCollection("tasks", "createdAtUtc", "Tasks Export", userId, fromUtc, toUtc, format);
    }

    [HttpGet("payroll")]
    public Task<IActionResult> ExportPayroll([FromQuery] string? userId, [FromQuery] DateTime? fromUtc, [FromQuery] DateTime? toUtc, [FromQuery] string format = "csv")
    {
        if (!IsAuthorizedForUser(userId))
        {
            return Task.FromResult((IActionResult)Forbid());
        }
        return ExportCollection("payroll", "createdAtUtc", "Payroll Export", userId, fromUtc, toUtc, format);
    }

    private bool IsAuthorizedForUser(string? userId)
    {
        if (string.IsNullOrWhiteSpace(userId))
        {
            return true;
        }

        var currentUserId = User.FindFirstValue(ClaimTypes.NameIdentifier);
        return User.IsInRole("admin") || string.Equals(currentUserId, userId, StringComparison.OrdinalIgnoreCase);
    }

    private async Task<IActionResult> ExportCollection(string collection, string dateField, string title, string? userId, DateTime? fromUtc, DateTime? toUtc, string format)
    {
        var query = _db.Collection(collection).OrderByDescending(dateField).Limit(500);

        if (!string.IsNullOrWhiteSpace(userId))
        {
            query = query.WhereEqualTo("userId", userId);
        }

        if (fromUtc.HasValue)
        {
            query = query.WhereGreaterThanOrEqualTo(dateField, fromUtc.Value);
        }

        if (toUtc.HasValue)
        {
            query = query.WhereLessThanOrEqualTo(dateField, toUtc.Value);
        }

        var snapshot = await query.GetSnapshotAsync();
        var rows = snapshot.Documents.Select(doc =>
        {
            var row = new Dictionary<string, object>(doc.ToDictionary())
            {
                ["id"] = doc.Id
            };
            return (IDictionary<string, object>)row;
        }).ToList();

        if (format.Equals("pdf", StringComparison.OrdinalIgnoreCase))
        {
            var pdfBytes = _exportService.GeneratePdf(title, rows);
            return File(pdfBytes, "application/pdf", $"{collection}-export.pdf");
        }

        var csvBytes = _exportService.GenerateCsv(rows);
        return File(csvBytes, "text/csv", $"{collection}-export.csv");
    }
}
