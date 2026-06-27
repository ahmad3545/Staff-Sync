namespace StaffSync.Api.Models;

public class VoiceResponse
{
    public string AudioBase64 { get; set; } = "";
    public string MimeType { get; set; } = "audio/mpeg";
}
