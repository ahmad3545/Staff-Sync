using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Google.Cloud.Firestore;
using StaffSync.Api.Models;
using StaffSync.Api.Services;

namespace StaffSync.Api.Controllers;

[ApiController]
[Route("api/ml")]
[Authorize]
public class MlController : ControllerBase
{
    private readonly PerformancePredictionService _predictionService;
    private readonly FirestoreDb _db;

    public MlController(PerformancePredictionService predictionService, FirestoreDb db)
    {
        _predictionService = predictionService;
        _db = db;
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

    [HttpGet("absentee-predictions")]
    [Authorize(Policy = "Admin")]
    public async Task<IActionResult> AbsenteePredictions()
    {
        var today = DateTime.UtcNow.Date;
        var historyStart = today.AddDays(-30);

        var usersSnapshot = await _db.Collection("users").Limit(300).GetSnapshotAsync();
        var attendanceSnapshot = await _db.Collection("attendance")
            .WhereGreaterThanOrEqualTo("timestampUtc", historyStart)
            .Limit(2000)
            .GetSnapshotAsync();
        var tasksSnapshot = await _db.Collection("tasks")
            .OrderByDescending("createdAtUtc")
            .Limit(1000)
            .GetSnapshotAsync();

        var users = usersSnapshot.Documents.Select(doc =>
        {
            var data = doc.ToDictionary();
            var name = data.TryGetValue("fullName", out var fullName) ? fullName?.ToString() : null;
            var department = data.TryGetValue("departmentId", out var departmentId) ? departmentId?.ToString() : null;
            return new
            {
                Id = doc.Id,
                Name = string.IsNullOrWhiteSpace(name) ? doc.Id : name,
                Department = string.IsNullOrWhiteSpace(department) ? "-" : department
            };
        }).ToList();

        var attendanceByUser = attendanceSnapshot.Documents
            .Select(doc => doc.ToDictionary())
            .Where(data => data.TryGetValue("userId", out var userId) && !string.IsNullOrWhiteSpace(userId?.ToString()))
            .GroupBy(data => data["userId"]!.ToString()!);

        var attendanceMap = attendanceByUser.ToDictionary(group => group.Key, group => group.ToList());

        var taskMap = tasksSnapshot.Documents
            .Select(doc => doc.ToDictionary())
            .Where(data => data.TryGetValue("userId", out var userId) && !string.IsNullOrWhiteSpace(userId?.ToString()))
            .GroupBy(data => data["userId"]!.ToString()!)
            .ToDictionary(group => group.Key, group => group.ToList());

        var workingDays = Enumerable.Range(0, 30)
            .Select(offset => today.AddDays(-offset))
            .Where(IsWorkDay)
            .ToList();

        var predictions = users.Select(user =>
        {
            var records = attendanceMap.TryGetValue(user.Id, out var userRecords)
                ? userRecords
                : new List<Dictionary<string, object>>();
            var tasks = taskMap.TryGetValue(user.Id, out var userTasks)
                ? userTasks
                : new List<Dictionary<string, object>>();

            var presentDates = records
                .Where(data =>
                {
                    var status = GetString(data, "status").ToLowerInvariant();
                    return status == "present" || status == "check_in";
                })
                .Select(data => ParseDate(data.TryGetValue("timestampUtc", out var timestamp) ? timestamp : null)?.Date)
                .Where(date => date.HasValue)
                .Select(date => date!.Value)
                .Distinct()
                .ToHashSet();

            var explicitAbsentDates = records
                .Where(data => GetString(data, "status").Equals("absent", StringComparison.OrdinalIgnoreCase))
                .Select(data => ParseDate(data.TryGetValue("timestampUtc", out var timestamp) ? timestamp : null)?.Date)
                .Where(date => date.HasValue)
                .Select(date => date!.Value)
                .Distinct()
                .ToHashSet();

            var missingDates = workingDays
                .Where(day => !presentDates.Contains(day) && !explicitAbsentDates.Contains(day))
                .ToList();

            var absentDates = explicitAbsentDates.Concat(missingDates).Distinct().ToList();
            var attendanceRate = workingDays.Count == 0 ? 1 : presentDates.Count / (double)workingDays.Count;

            var openTasks = tasks.Where(IsOpenTask).ToList();
            var completedTasks = tasks.Count(IsClosedTask);
            var overdueTasks = openTasks.Count(task =>
            {
                var due = ParseDate(task.TryGetValue("dueDateUtc", out var dueDate) ? dueDate : null);
                return due != null && due.Value.Date < today;
            });
            var highPriorityTasks = openTasks.Count(task =>
            {
                var priority = GetString(task, "priority").ToLowerInvariant();
                return priority == "high" || priority == "urgent";
            });
            var completionRate = tasks.Count == 0 ? 1 : completedTasks / (double)tasks.Count;

            var upcomingDays = Enumerable.Range(1, 7)
                .Select(offset => today.AddDays(offset))
                .ToList();

            var dailyWorkload = upcomingDays.Select(day =>
            {
                var dueCount = openTasks.Count(task =>
                {
                    var due = ParseDate(task.TryGetValue("dueDateUtc", out var dueDate) ? dueDate : null);
                    return due != null && due.Value.Date == day;
                });
                var load = dueCount + overdueTasks;
                var level = load >= 3 ? "high" : load == 0 ? "low" : "medium";
                return new
                {
                    Date = day.ToString("yyyy-MM-dd"),
                    Label = day.ToString("ddd, MMM dd"),
                    Level = level,
                    DueTasks = dueCount
                };
            }).ToList();

            var absentWeekdays = absentDates
                .GroupBy(date => date.DayOfWeek)
                .ToDictionary(group => group.Key, group => group.Count());
            var likelyAbsentDays = upcomingDays
                .Select(day =>
                {
                    absentWeekdays.TryGetValue(day.DayOfWeek, out var patternCount);
                    var dueCount = dailyWorkload.First(workload => workload.Date == day.ToString("yyyy-MM-dd")).DueTasks;
                    var probability = Math.Clamp((1 - attendanceRate) * 55 + patternCount * 12 - dueCount * 8, 5, 92);
                    return new
                    {
                        Date = day.ToString("yyyy-MM-dd"),
                        Label = day.ToString("ddd, MMM dd"),
                        Probability = Math.Round(probability),
                        Reason = patternCount > 0
                            ? "Past absence pattern on this weekday"
                            : dueCount == 0
                                ? "Low task load day"
                                : "Moderate prediction from attendance trend"
                    };
                })
                .OrderByDescending(day => day.Probability)
                .Take(2)
                .ToList();

            var leaveFriendlyDays = dailyWorkload
                .Where(day => day.Level == "low")
                .Take(2)
                .Select(day => new
                {
                    day.Date,
                    day.Label,
                    Reason = "No due tasks found for this day"
                })
                .ToList();

            var workloadPressure = overdueTasks >= 2 || highPriorityTasks >= 2 || openTasks.Count >= 5
                ? "high"
                : openTasks.Count == 0
                    ? "low"
                    : "medium";

            var riskScore = Math.Clamp(
                (1 - attendanceRate) * 58 +
                absentDates.Count * 1.2 +
                overdueTasks * 7 +
                highPriorityTasks * 4 +
                (1 - completionRate) * 18,
                0,
                100);
            var riskLevel = riskScore >= 70 ? "high" : riskScore >= 40 ? "medium" : "low";

            return new
            {
                UserId = user.Id,
                Name = user.Name,
                Department = user.Department,
                RiskLevel = riskLevel,
                RiskScore = Math.Round(riskScore),
                AttendanceRate = Math.Round(attendanceRate * 100),
                PresentDays = presentDates.Count,
                AbsentDays = absentDates.Count,
                OpenTasks = openTasks.Count,
                OverdueTasks = overdueTasks,
                HighPriorityTasks = highPriorityTasks,
                WorkloadPressure = workloadPressure,
                LikelyAbsentDays = likelyAbsentDays,
                LeaveFriendlyDays = leaveFriendlyDays,
                DailyWorkload = dailyWorkload,
                Summary = BuildSummary(riskLevel, workloadPressure, absentDates.Count, openTasks.Count)
            };
        })
        .OrderByDescending(item => item.RiskScore)
        .ToList();

        return Ok(new
        {
            generatedAtUtc = DateTime.UtcNow.ToString("o"),
            predictions
        });
    }

    private static string GetString(Dictionary<string, object> data, string key)
    {
        return data.TryGetValue(key, out var value) ? value?.ToString() ?? "" : "";
    }

    private static bool IsOpenTask(Dictionary<string, object> task)
    {
        var status = GetString(task, "status").ToLowerInvariant();
        return status != "completed" && status != "verified" && status != "approved";
    }

    private static bool IsClosedTask(Dictionary<string, object> task)
    {
        var status = GetString(task, "status").ToLowerInvariant();
        return status == "completed" || status == "verified" || status == "approved";
    }

    private static bool IsWorkDay(DateTime day)
    {
        return day.DayOfWeek != DayOfWeek.Saturday && day.DayOfWeek != DayOfWeek.Sunday;
    }

    private static DateTime? ParseDate(object? value)
    {
        return value switch
        {
            Timestamp timestamp => timestamp.ToDateTime().ToUniversalTime(),
            DateTime dateTime => dateTime.ToUniversalTime(),
            string text when DateTime.TryParse(text, out var parsed) => parsed.ToUniversalTime(),
            _ => null
        };
    }

    private static string BuildSummary(string riskLevel, string workloadPressure, int absentDays, int openTasks)
    {
        if (riskLevel == "high")
        {
            return $"High absence risk: {absentDays} missed work days in recent history and {openTasks} open tasks.";
        }

        if (workloadPressure == "high")
        {
            return $"Workload is high with {openTasks} open tasks. Avoid approving leave on heavy task days.";
        }

        if (workloadPressure == "low")
        {
            return "Low workload. Upcoming low-task days are better leave windows.";
        }

        return "Moderate absence risk. Review upcoming task due dates before approving leave.";
    }
}
