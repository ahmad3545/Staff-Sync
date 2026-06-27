using System.ComponentModel.DataAnnotations;

namespace StaffSync.Api.Models;

public class VoiceRequest
{
    [Required]
    public string Text { get; set; } = "";

    public string LanguageCode { get; set; } = "ur-PK";
    public string? VoiceName { get; set; }
    public string AudioEncoding { get; set; } = "MP3";
}
