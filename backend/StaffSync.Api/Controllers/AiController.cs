using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using StaffSync.Api.Models;
using StaffSync.Api.Services;

namespace StaffSync.Api.Controllers;

[ApiController]
[Route("api/ai")]
[Authorize]
public class AiController : ControllerBase
{
    private readonly TranslationService _translationService;
    private readonly TextToSpeechService _textToSpeechService;

    public AiController(TranslationService translationService, TextToSpeechService textToSpeechService)
    {
        _translationService = translationService;
        _textToSpeechService = textToSpeechService;
    }

    [HttpPost("translate")]
    [Authorize]
    public IActionResult Translate([FromBody] TranslateRequest request)
    {
        var response = _translationService.Translate(request);
        return Ok(response);
    }

    [HttpPost("voice")]
    [Authorize]
    public IActionResult Voice([FromBody] VoiceRequest request)
    {
        var response = _textToSpeechService.Synthesize(request);
        return Ok(response);
    }
}
