using System.ComponentModel.DataAnnotations;

namespace StaffSync.Api.Models;

public class NotificationBroadcastRequest
{
    [Required]
    [MaxLength(200)]
    public string Title { get; set; } = "";

    [MaxLength(2000)]
    public string? Body { get; set; }

    [MaxLength(100)]
    public string? Type { get; set; }
}
