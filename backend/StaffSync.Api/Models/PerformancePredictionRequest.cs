using System.ComponentModel.DataAnnotations;

namespace StaffSync.Api.Models;

public class PerformancePredictionRequest
{
    [Required]
    public string UserId { get; set; } = "";

    [Range(0, 1)]
    public double AttendanceRate { get; set; }

    [Range(0, 1)]
    public double TaskCompletionRate { get; set; }

    [Range(0, 30)]
    public double LeaveCount { get; set; }
}
