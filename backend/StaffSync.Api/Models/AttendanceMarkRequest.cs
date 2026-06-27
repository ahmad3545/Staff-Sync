using System.ComponentModel.DataAnnotations;

namespace StaffSync.Api.Models;

public class AttendanceMarkRequest
{
    [Required]
    public string UserId { get; set; } = "";

    [Required]
    public DateTime TimestampUtc { get; set; } = DateTime.UtcNow;

    [Range(-90, 90)]
    public double? Latitude { get; set; }

    [Range(-180, 180)]
    public double? Longitude { get; set; }
    public string? Status { get; set; }
}
