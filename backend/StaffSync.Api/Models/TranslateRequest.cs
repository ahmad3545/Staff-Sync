using System.ComponentModel.DataAnnotations;

namespace StaffSync.Api.Models;

public class TranslateRequest
{
    [Required]
    public string Text { get; set; } = "";

    public string? SourceLanguage { get; set; }

    [Required]
    public string TargetLanguage { get; set; } = "ur";
}
