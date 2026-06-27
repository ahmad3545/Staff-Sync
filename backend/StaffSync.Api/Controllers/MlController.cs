using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using StaffSync.Api.Models;
using StaffSync.Api.Services;

namespace StaffSync.Api.Controllers;

[ApiController]
[Route("api/ml")]
[Authorize]
public class MlController : ControllerBase
{
    private readonly PerformancePredictionService _predictionService;

    public MlController(PerformancePredictionService predictionService)
    {
        _predictionService = predictionService;
    }

    [HttpPost("predict")]
    public IActionResult Predict([FromBody] PerformancePredictionRequest request)
    {
        if (string.IsNullOrWhiteSpace(request.UserId))
        {
            return BadRequest("UserId required.");
        }

        var response = _predictionService.Predict(request);
        return Ok(response);
    }
}
