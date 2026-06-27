using Microsoft.ML.Data;

namespace StaffSync.Api.Models;

public class PerformanceModelInput
{
    [ColumnName("AttendanceRate")]
    public float AttendanceRate { get; set; }

    [ColumnName("TaskCompletionRate")]
    public float TaskCompletionRate { get; set; }

    [ColumnName("LeaveCount")]
    public float LeaveCount { get; set; }
}
