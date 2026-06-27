using Microsoft.ML;
using StaffSync.Api.Models;
using StaffSync.Api.Options;
using Microsoft.Extensions.Options;

namespace StaffSync.Api.Services;

public class PerformancePredictionService
{
    private readonly MLContext _mlContext = new();
    private readonly MlOptions _options;
    private readonly IWebHostEnvironment _environment;
    private readonly ILogger<PerformancePredictionService> _logger;
    private ITransformer? _model;

    public PerformancePredictionService(
        IOptions<MlOptions> options,
        IWebHostEnvironment environment,
        ILogger<PerformancePredictionService> logger)
    {
        _options = options.Value;
        _environment = environment;
        _logger = logger;

        TryLoadModel();
    }

    public PerformancePredictionResponse Predict(PerformancePredictionRequest request)
    {
        if (_model != null)
        {
            try
            {
                var engine = _mlContext.Model.CreatePredictionEngine<PerformanceModelInput, PerformanceModelOutput>(_model);
                var prediction = engine.Predict(new PerformanceModelInput
                {
                    AttendanceRate = (float)Math.Clamp(request.AttendanceRate, 0, 1),
                    TaskCompletionRate = (float)Math.Clamp(request.TaskCompletionRate, 0, 1),
                    LeaveCount = (float)Math.Clamp(request.LeaveCount, 0, 30)
                });

                var score = prediction.Score;
                if (score <= 1)
                {
                    score *= 100;
                }

                return BuildResponse(request.UserId, Math.Clamp(score, 0, 100));
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "ML model prediction failed. Falling back to heuristic.");
            }
        }

        var attendanceScore = Math.Clamp(request.AttendanceRate, 0, 1) * 50;
        var taskScore = Math.Clamp(request.TaskCompletionRate, 0, 1) * 40;
        var leavePenalty = Math.Clamp(request.LeaveCount, 0, 30) * 0.5;
        var rawScore = Math.Clamp(attendanceScore + taskScore - leavePenalty, 0, 100);

        return BuildResponse(request.UserId, rawScore);
    }

    private void TryLoadModel()
    {
        if (string.IsNullOrWhiteSpace(_options.ModelPath))
        {
            return;
        }

        var modelPath = _options.ModelPath;
        if (!Path.IsPathRooted(modelPath))
        {
            modelPath = Path.Combine(_environment.ContentRootPath, modelPath);
        }

        if (!File.Exists(modelPath))
        {
            _logger.LogInformation("ML model not found at {ModelPath}.", modelPath);
            return;
        }

        try
        {
            using var stream = File.OpenRead(modelPath);
            _model = _mlContext.Model.Load(stream, out _);
            _logger.LogInformation("ML model loaded from {ModelPath}.", modelPath);
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Failed to load ML model from {ModelPath}.", modelPath);
        }
    }

    private static PerformancePredictionResponse BuildResponse(string userId, double score)
    {
        var riskLevel = score switch
        {
            < 40 => "high",
            < 70 => "medium",
            _ => "low"
        };

        return new PerformancePredictionResponse
        {
            UserId = userId,
            RiskLevel = riskLevel,
            Score = Math.Round(score, 2)
        };
    }
}
