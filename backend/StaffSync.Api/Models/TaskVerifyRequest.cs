using System.ComponentModel.DataAnnotations;

namespace StaffSync.Api.Models;

public class TaskVerifyRequest
{
    [Required]
    public string TaskId { get; set; } = "";

    [Required]
    [MaxLength(50)]
    public string Status { get; set; } = "verified";
    public string? ReviewerId { get; set; }
    [MaxLength(500)]
    public string? Notes { get; set; }
}
