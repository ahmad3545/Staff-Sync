using System.ComponentModel.DataAnnotations;

namespace StaffSync.Api.Models;

public class PayrollSettingsUpdateRequest
{
    [Required]
    public string UserId { get; set; } = "";

    [Range(0, double.MaxValue)]
    public decimal BaseSalary { get; set; }

    [Range(0, double.MaxValue)]
    public decimal OvertimeRate { get; set; }
}