using System.ComponentModel.DataAnnotations;

namespace StaffSync.Api.Models;

public class AdminRoleUpdateRequest
{
    [Required]
    public string UserId { get; set; } = "";

    [Required]
    [MaxLength(50)]
    public string Role { get; set; } = "employee";
}
