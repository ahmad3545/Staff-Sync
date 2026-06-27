using Microsoft.ML.Data;

namespace StaffSync.Api.Models;

public class PerformanceModelOutput
{
    [ColumnName("Score")]
    public float Score { get; set; }
}
