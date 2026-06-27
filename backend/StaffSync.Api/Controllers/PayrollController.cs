using Google.Cloud.Firestore;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using System.Security.Claims;
using StaffSync.Api.Models;
using StaffSync.Api.Services;

namespace StaffSync.Api.Controllers;

[ApiController]
[Route("api/payroll")]
[Authorize]
public class PayrollController : ControllerBase
{
    private const decimal FixedOvertimeRate = 2000m;
    private readonly FirestoreDb _db;
    private readonly PayrollService _payrollService;
    private readonly PayrollPdfBuilder _pdfBuilder;

    public PayrollController(FirestoreDb db, PayrollService payrollService, PayrollPdfBuilder pdfBuilder)
    {
        _db = db;
        _payrollService = payrollService;
        _pdfBuilder = pdfBuilder;
    }

    [HttpPost("calculate")]
    public async Task<IActionResult> Calculate([FromBody] PayrollCalculateRequest request)
    {
        var currentUserId = User.FindFirstValue(ClaimTypes.NameIdentifier);
        var isAdmin = User.Claims.Any(claim => claim.Type == "role" && claim.Value == "admin");
        if (!isAdmin && !string.Equals(currentUserId, request.UserId, StringComparison.OrdinalIgnoreCase))
        {
            return Forbid();
        }

        var userSnapshot = await _db.Collection("users").Document(request.UserId).GetSnapshotAsync();
        var userData = userSnapshot.Exists
            ? userSnapshot.ToDictionary()
            : new Dictionary<string, object>();

        if (request.PeriodStartUtc == default)
        {
            request.PeriodStartUtc = ReadDateTime(userData, "createdAtUtc") ?? DateTime.UtcNow;
        }

        if (request.PeriodEndUtc == default)
        {
            request.PeriodEndUtc = DateTime.UtcNow;
        }

        if (request.PeriodEndUtc < request.PeriodStartUtc)
        {
            request.PeriodEndUtc = DateTime.UtcNow;
        }

        if (request.BaseSalary <= 0)
        {
            request.BaseSalary = ReadDecimal(userData, "baseSalary");
        }

        if (request.BaseSalary <= 0)
        {
            return BadRequest("Base salary is required.");
        }

        request.OvertimeRate = FixedOvertimeRate;

        var record = _payrollService.Calculate(request);
        var data = new Dictionary<string, object?>
        {
            ["userId"] = record.UserId,
            ["periodStartUtc"] = record.PeriodStartUtc,
            ["periodEndUtc"] = record.PeriodEndUtc,
            ["baseSalary"] = Convert.ToDouble(record.BaseSalary),
            ["allowances"] = Convert.ToDouble(record.Allowances),
            ["deductions"] = Convert.ToDouble(record.Deductions),
            ["overtimeHours"] = Convert.ToDouble(record.OvertimeHours),
            ["overtimeRate"] = Convert.ToDouble(record.OvertimeRate),
            ["netSalary"] = Convert.ToDouble(record.NetSalary),
            ["status"] = record.Status,
            ["createdAtUtc"] = record.CreatedAtUtc
        };

        var docRef = await _db.Collection("payroll").AddAsync(data);
        record.Id = docRef.Id;

        return Ok(new { id = record.Id, netSalary = record.NetSalary });
    }

    [HttpGet("{userId}")]
    public async Task<IActionResult> GetPayroll(string userId)
    {
        if (string.IsNullOrWhiteSpace(userId))
        {
            return BadRequest("UserId required.");
        }

        var currentUserId = User.FindFirstValue(ClaimTypes.NameIdentifier);
        var isAdmin = User.Claims.Any(claim => claim.Type == "role" && claim.Value == "admin");
        if (!isAdmin && !string.Equals(currentUserId, userId, StringComparison.OrdinalIgnoreCase))
        {
            return Forbid();
        }

        var snapshot = await _db.Collection("payroll")
            .WhereEqualTo("userId", userId)
            .OrderByDescending("createdAtUtc")
            .Limit(50)
            .GetSnapshotAsync();

        var results = snapshot.Documents.Select(doc => new { id = doc.Id, data = doc.ToDictionary() });
        return Ok(results);
    }

    [HttpGet("payslip/{payrollId}")]
    public async Task<IActionResult> GetPayslip(string payrollId, [FromQuery] string format = "json")
    {
        if (string.IsNullOrWhiteSpace(payrollId))
        {
            return BadRequest("PayrollId required.");
        }

        var currentUserId = User.FindFirstValue(ClaimTypes.NameIdentifier);
        var isAdmin = User.Claims.Any(claim => claim.Type == "role" && claim.Value == "admin");

        var docRef = _db.Collection("payroll").Document(payrollId);
        var snapshot = await docRef.GetSnapshotAsync();

        if (!snapshot.Exists)
        {
            return NotFound();
        }

        var record = MapPayrollRecord(snapshot.Id, snapshot.ToDictionary());

        if (!isAdmin && !string.Equals(currentUserId, record.UserId, StringComparison.OrdinalIgnoreCase))
        {
            return Forbid();
        }

        if (format.Equals("pdf", StringComparison.OrdinalIgnoreCase))
        {
            var pdfBytes = _pdfBuilder.Build(record);
            return File(pdfBytes, "application/pdf", $"payslip-{record.Id}.pdf");
        }

        return Ok(record);
    }

    private static PayrollRecord MapPayrollRecord(string id, IReadOnlyDictionary<string, object> data)
    {
        return new PayrollRecord
        {
            Id = id,
            UserId = data.TryGetValue("userId", out var userId) ? userId?.ToString() ?? "" : "",
            PeriodStartUtc = data.TryGetValue("periodStartUtc", out var start) ? (DateTime)start : DateTime.UtcNow,
            PeriodEndUtc = data.TryGetValue("periodEndUtc", out var end) ? (DateTime)end : DateTime.UtcNow,
            BaseSalary = data.TryGetValue("baseSalary", out var baseSalary) ? Convert.ToDecimal(baseSalary) : 0,
            Allowances = data.TryGetValue("allowances", out var allowances) ? Convert.ToDecimal(allowances) : 0,
            Deductions = data.TryGetValue("deductions", out var deductions) ? Convert.ToDecimal(deductions) : 0,
            OvertimeHours = data.TryGetValue("overtimeHours", out var overtimeHours) ? Convert.ToDecimal(overtimeHours) : 0,
            OvertimeRate = data.TryGetValue("overtimeRate", out var overtimeRate) ? Convert.ToDecimal(overtimeRate) : 0,
            NetSalary = data.TryGetValue("netSalary", out var netSalary) ? Convert.ToDecimal(netSalary) : 0,
            Status = data.TryGetValue("status", out var status) ? status?.ToString() ?? "processed" : "processed",
            CreatedAtUtc = data.TryGetValue("createdAtUtc", out var created) ? (DateTime)created : DateTime.UtcNow
        };
    }

    private static DateTime? ReadDateTime(IReadOnlyDictionary<string, object> data, string key)
    {
        if (!data.TryGetValue(key, out var value) || value == null)
        {
            return null;
        }

        if (value is DateTime dateTime)
        {
            return dateTime;
        }

        if (value is Timestamp timestamp)
        {
            return timestamp.ToDateTime();
        }

        return DateTime.TryParse(value.ToString(), out var parsed) ? parsed : null;
    }

    private static decimal ReadDecimal(IReadOnlyDictionary<string, object> data, string key)
    {
        if (!data.TryGetValue(key, out var value) || value == null)
        {
            return 0;
        }

        if (value is decimal decimalValue)
        {
            return decimalValue;
        }

        if (value is double doubleValue)
        {
            return (decimal)doubleValue;
        }

        if (value is int intValue)
        {
            return intValue;
        }

        return decimal.TryParse(value.ToString(), out var parsed) ? parsed : 0;
    }

    [HttpPost("dev/create")]
    [AllowAnonymous]
    public async Task<IActionResult> CreateTestPayroll([FromBody] PayrollRecord record)
    {
        if (string.IsNullOrWhiteSpace(record.UserId))
        {
            return BadRequest("UserId required.");
        }

        var data = new Dictionary<string, object?>
        {
            ["userId"] = record.UserId,
            ["periodStartUtc"] = record.PeriodStartUtc,
            ["periodEndUtc"] = record.PeriodEndUtc,
            ["baseSalary"] = Convert.ToDouble(record.BaseSalary),
            ["allowances"] = Convert.ToDouble(record.Allowances),
            ["deductions"] = Convert.ToDouble(record.Deductions),
            ["overtimeHours"] = Convert.ToDouble(record.OvertimeHours),
            ["overtimeRate"] = Convert.ToDouble(record.OvertimeRate),
            ["netSalary"] = Convert.ToDouble(record.NetSalary),
            ["status"] = record.Status,
            ["createdAtUtc"] = DateTime.UtcNow
        };

        var docRef = await _db.Collection("payroll").AddAsync(data);
        return Ok(new { id = docRef.Id, netSalary = record.NetSalary });
    }
}
