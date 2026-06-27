using System.ComponentModel.DataAnnotations;

namespace StaffSync.Api.Models;

public class LeaveRequestCreate
{
    [Required]
    public string UserId { get; set; } = "";

    [Required]
    public DateTime StartDateUtc { get; set; }

    [Required]
    public DateTime EndDateUtc { get; set; }

    [Required]
    [MinLength(3)]
    public string Reason { get; set; } = "";
}
