using System.ComponentModel.DataAnnotations;

namespace StaffSync.Api.Models;

public class UserProfileUpdate
{
    [Required]
    public string UserId { get; set; } = "";
    [MaxLength(200)]
    public string? FullName { get; set; }
    [MaxLength(100)]
    public string? DepartmentId { get; set; }
    [MaxLength(50)]
    public string? Role { get; set; }
    [MaxLength(30)]
    public string? Phone { get; set; }
    [MaxLength(200)]
    public string? Email { get; set; }
}
