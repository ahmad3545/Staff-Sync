using StaffSync.Api.Models;

namespace StaffSync.Api.Services;

public class PayrollService
{
    public PayrollRecord Calculate(PayrollCalculateRequest request)
    {
        var overtimePay = request.OvertimeHours * request.OvertimeRate;
        var netSalary = request.BaseSalary + request.Allowances + overtimePay - request.Deductions;

        if (netSalary < 0)
        {
            netSalary = 0;
        }

        return new PayrollRecord
        {
            UserId = request.UserId,
            PeriodStartUtc = request.PeriodStartUtc,
            PeriodEndUtc = request.PeriodEndUtc,
            BaseSalary = request.BaseSalary,
            Allowances = request.Allowances,
            Deductions = request.Deductions,
            OvertimeHours = request.OvertimeHours,
            OvertimeRate = request.OvertimeRate,
            NetSalary = netSalary,
            CreatedAtUtc = DateTime.UtcNow,
            Status = "processed"
        };
    }
}
