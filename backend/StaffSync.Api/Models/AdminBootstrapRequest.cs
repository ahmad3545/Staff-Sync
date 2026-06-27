using System.ComponentModel.DataAnnotations;

namespace StaffSync.Api.Models;

public class AdminBootstrapRequest
{
    [Required]
    public string UserId { get; set; } = "";
}
