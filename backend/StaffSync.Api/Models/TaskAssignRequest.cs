using System.ComponentModel.DataAnnotations;

namespace StaffSync.Api.Models;

public class TaskAssignRequest
{
    [Required]
    public string UserId { get; set; } = "";

    [Required]
    [MaxLength(200)]
    public string Title { get; set; } = "";

    [MaxLength(2000)]
    public string? Description { get; set; }
    public DateTime? DueDateUtc { get; set; }

    [MaxLength(20)]
    public string? Priority { get; set; }
}
