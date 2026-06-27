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
        var isAdmin = User.Claims.Any(c =>
            c.Type == "role" && c.Value.Equals("admin", StringComparison.OrdinalIgnoreCase));
        return isAdmin || string.Equals(currentUserId, userId, StringComparison.OrdinalIgnoreCase);
    }

    private async Task<IActionResult> ExportCollection(string collection, string dateField, string title, string? userId, DateTime? fromUtc, DateTime? toUtc, string format)
    {
        var query = _db.Collection(collection).Limit(1000);
        var snapshot = await query.GetSnapshotAsync();
        var rows = snapshot.Documents
            .Select(doc =>
            {
                var row = new Dictionary<string, object>(doc.ToDictionary())
                {
                    ["id"] = doc.Id
                };
                NormalizeDate(row, dateField);
                NormalizeDate(row, "createdAtUtc");
                NormalizeDate(row, "updatedAtUtc");
                NormalizeDate(row, "timestampUtc");
                NormalizeDate(row, "startDateUtc");
                NormalizeDate(row, "endDateUtc");
                NormalizeDate(row, "dueDateUtc");
                return row;
            })
            .Where(row => MatchesUser(row, userId))
            .Where(row => MatchesDateRange(row, dateField, fromUtc, toUtc))
            .OrderByDescending(row => ParseDate(row.TryGetValue(dateField, out var value) ? value : null) ?? DateTime.MinValue)
            .Take(500)
            .Cast<IDictionary<string, object>>()
            .ToList();

        if (format.Equals("pdf", StringComparison.OrdinalIgnoreCase))
        {
            var pdfBytes = _exportService.GeneratePdf(title, rows);
            return File(pdfBytes, "application/pdf", $"{collection}-export.pdf");
        }

        var csvBytes = _exportService.GenerateCsv(rows);
        return File(csvBytes, "text/csv", $"{collection}-export.csv");
    }

    private static bool MatchesUser(Dictionary<string, object> row, string? userId)
    {
        if (string.IsNullOrWhiteSpace(userId))
        {
            return true;
        }

        return row.TryGetValue("userId", out var value) &&
            string.Equals(value?.ToString(), userId, StringComparison.OrdinalIgnoreCase);
    }

    private static bool MatchesDateRange(Dictionary<string, object> row, string dateField, DateTime? fromUtc, DateTime? toUtc)
    {
        if (!fromUtc.HasValue && !toUtc.HasValue)
        {
            return true;
        }

        var date = ParseDate(row.TryGetValue(dateField, out var value) ? value : null);
        if (!date.HasValue)
        {
            return false;
        }

        if (fromUtc.HasValue && date.Value < fromUtc.Value.ToUniversalTime())
        {
            return false;
        }

        if (toUtc.HasValue && date.Value > toUtc.Value.ToUniversalTime())
        {
            return false;
        }

        return true;
    }

    private static void NormalizeDate(Dictionary<string, object> row, string key)
    {
        if (!row.TryGetValue(key, out var value))
        {
            return;
        }

        var date = ParseDate(value);
        if (date.HasValue)
        {
            row[key] = date.Value.ToUniversalTime().ToString("o");
        }
    }

    private static DateTime? ParseDate(object? value)
    {
        return value switch
        {
            Timestamp timestamp => timestamp.ToDateTime().ToUniversalTime(),
            DateTime dateTime => dateTime.ToUniversalTime(),
            string text when DateTime.TryParse(text, out var parsed) => parsed.ToUniversalTime(),
            _ => null
        };
    }
}
