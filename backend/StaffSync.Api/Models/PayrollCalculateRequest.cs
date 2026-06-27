using System.ComponentModel.DataAnnotations;

namespace StaffSync.Api.Models;

public class PayrollCalculateRequest
{
    [Required]
    public string UserId { get; set; } = "";

    [Required]
    public DateTime PeriodStartUtc { get; set; }

    [Required]
    public DateTime PeriodEndUtc { get; set; }

    [Range(0, double.MaxValue)]
    public decimal BaseSalary { get; set; }

    [Range(0, double.MaxValue)]
    public decimal Allowances { get; set; }

    [Range(0, double.MaxValue)]
    public decimal Deductions { get; set; }

    [Range(0, double.MaxValue)]
    public decimal OvertimeHours { get; set; }

    [Range(0, double.MaxValue)]
    public decimal OvertimeRate { get; set; }
}
