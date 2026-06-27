using System.ComponentModel.DataAnnotations;

namespace StaffSync.Api.Models;

public class ReportRequest
{
    [Required]
    public string UserId { get; set; } = "";

    [Required]
    public DateTime FromUtc { get; set; }

    [Required]
    public DateTime ToUtc { get; set; }

    [Required]
    [MaxLength(50)]
    public string Type { get; set; } = "attendance";
}
