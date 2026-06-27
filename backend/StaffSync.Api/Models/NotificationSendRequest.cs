using System.ComponentModel.DataAnnotations;

namespace StaffSync.Api.Models;

public class NotificationSendRequest
{
    [Required]
    public string UserId { get; set; } = "";

    [Required]
    [MaxLength(200)]
    public string Title { get; set; } = "";

    [Required]
    [MaxLength(2000)]
    public string Body { get; set; } = "";

    [MaxLength(100)]
    public string? Type { get; set; }
}
