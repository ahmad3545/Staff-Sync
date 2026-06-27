using Google.Apis.Auth.OAuth2;
using Google.Cloud.Translation.V2;
using Microsoft.Extensions.Options;
using StaffSync.Api.Models;
using StaffSync.Api.Options;

namespace StaffSync.Api.Services;

public class TranslationService
{
    private readonly FirebaseOptions _firebaseOptions;

    public TranslationService(IOptions<FirebaseOptions> firebaseOptions)
    {
        _firebaseOptions = firebaseOptions.Value;
    }

    public TranslateResponse Translate(TranslateRequest request)
    {
        var credential = string.IsNullOrWhiteSpace(_firebaseOptions.CredentialPath)
            ? GoogleCredential.GetApplicationDefault()
            : GoogleCredential.FromFile(_firebaseOptions.CredentialPath);

        var client = TranslationClient.Create(credential);
        var response = client.TranslateText(
            request.Text,
            request.TargetLanguage,
            string.IsNullOrWhiteSpace(request.SourceLanguage) ? null : request.SourceLanguage
        );

        return new TranslateResponse
        {
            TranslatedText = response.TranslatedText ?? string.Empty,
            DetectedSourceLanguage = response.DetectedSourceLanguage
        };
    }
}
