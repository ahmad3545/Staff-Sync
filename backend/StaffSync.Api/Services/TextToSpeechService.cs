using Google.Apis.Auth.OAuth2;
using Google.Cloud.TextToSpeech.V1;
using Microsoft.Extensions.Options;
using StaffSync.Api.Models;
using StaffSync.Api.Options;

namespace StaffSync.Api.Services;

public class TextToSpeechService
{
    private readonly FirebaseOptions _firebaseOptions;

    public TextToSpeechService(IOptions<FirebaseOptions> firebaseOptions)
    {
        _firebaseOptions = firebaseOptions.Value;
    }

    public VoiceResponse Synthesize(VoiceRequest request)
    {
        var credential = string.IsNullOrWhiteSpace(_firebaseOptions.CredentialPath)
            ? GoogleCredential.GetApplicationDefault()
            : GoogleCredential.FromFile(_firebaseOptions.CredentialPath);

        var client = new TextToSpeechClientBuilder { Credential = credential }.Build();
        var input = new SynthesisInput { Text = request.Text };

        var voice = new VoiceSelectionParams
        {
            LanguageCode = request.LanguageCode,
            Name = request.VoiceName
        };

        var encoding = request.AudioEncoding.ToUpperInvariant() switch
        {
            "LINEAR16" => AudioEncoding.Linear16,
            "OGG_OPUS" => AudioEncoding.OggOpus,
            _ => AudioEncoding.Mp3
        };

        var audioConfig = new AudioConfig { AudioEncoding = encoding };
        var response = client.SynthesizeSpeech(input, voice, audioConfig);
        var audioBytes = response.AudioContent.ToByteArray();

        return new VoiceResponse
        {
            AudioBase64 = Convert.ToBase64String(audioBytes),
            MimeType = encoding switch
            {
                AudioEncoding.Linear16 => "audio/wav",
                AudioEncoding.OggOpus => "audio/ogg",
                _ => "audio/mpeg"
            }
        };
    }
}
