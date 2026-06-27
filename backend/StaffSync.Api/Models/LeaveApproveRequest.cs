using System.ComponentModel.DataAnnotations;

namespace StaffSync.Api.Models;

public class LeaveApproveRequest
{
    [Required]
    public string LeaveId { get; set; } = "";

    [Required]
    [MaxLength(50)]
    public string Status { get; set; } = "approved";
    public string? ApproverId { get; set; }
    [MaxLength(500)]
    public string? Notes { get; set; }
}
