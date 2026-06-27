using System.ComponentModel.DataAnnotations;

namespace StaffSync.Api.Models;

public class DepartmentCreate
{
    [Required]
    [MaxLength(120)]
    public string Name { get; set; } = "";
    [MaxLength(500)]
    public string? Description { get; set; }
}
