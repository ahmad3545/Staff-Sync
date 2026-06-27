using System.ComponentModel.DataAnnotations;

namespace StaffSync.Api.Models;

public class ShiftAssignRequest
{
    [Required]
    public string ShiftId { get; set; } = "";

    [Required]
    public List<string> UserIds { get; set; } = new();
}
