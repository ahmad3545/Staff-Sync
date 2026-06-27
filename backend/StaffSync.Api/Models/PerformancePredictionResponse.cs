namespace StaffSync.Api.Models;

public class PerformancePredictionResponse
{
    public string UserId { get; set; } = "";
    public string RiskLevel { get; set; } = "low";
    public double Score { get; set; }
}
