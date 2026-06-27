using System.ComponentModel.DataAnnotations;

namespace StaffSync.Api.Models;

public class ShiftCreateRequest
{
    [Required]
    public string Name { get; set; } = "";

    [Required]
    public DateTime StartTimeUtc { get; set; }

    [Required]
    public DateTime EndTimeUtc { get; set; }

    public string? Location { get; set; }

    public string Status { get; set; } = "active";
}
