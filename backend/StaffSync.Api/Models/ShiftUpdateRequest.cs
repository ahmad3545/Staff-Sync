using System.ComponentModel.DataAnnotations;

namespace StaffSync.Api.Models;

public class ShiftUpdateRequest
{
    [Required]
    public string ShiftId { get; set; } = "";

    public string? Name { get; set; }
    public DateTime? StartTimeUtc { get; set; }
    public DateTime? EndTimeUtc { get; set; }
    public string? Location { get; set; }
    public string? Status { get; set; }
}
