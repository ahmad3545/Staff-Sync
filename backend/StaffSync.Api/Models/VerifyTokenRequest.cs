using System.ComponentModel.DataAnnotations;

namespace StaffSync.Api.Models;

public class VerifyTokenRequest
{
    [Required]
    public string IdToken { get; set; } = "";
}
