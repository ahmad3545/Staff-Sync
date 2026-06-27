namespace StaffSync.Api.Models;

public class PayrollRecord
{
    public string Id { get; set; } = "";
    public string UserId { get; set; } = "";
    public DateTime PeriodStartUtc { get; set; }
    public DateTime PeriodEndUtc { get; set; }
    public decimal BaseSalary { get; set; }
    public decimal Allowances { get; set; }
    public decimal Deductions { get; set; }
    public decimal OvertimeHours { get; set; }
    public decimal OvertimeRate { get; set; }
    public decimal NetSalary { get; set; }
    public string Status { get; set; } = "processed";
    public DateTime CreatedAtUtc { get; set; } = DateTime.UtcNow;
}
