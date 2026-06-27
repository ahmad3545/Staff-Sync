namespace StaffSync.Api.Models;

public class TranslateResponse
{
    public string TranslatedText { get; set; } = "";
    public string? DetectedSourceLanguage { get; set; }
}
