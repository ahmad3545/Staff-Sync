using System.ComponentModel.DataAnnotations;

namespace StaffSync.Api.Models;

public class AttendanceBatchMarkRequest
{
    [Required]
    public List<AttendanceMarkRequest> Records { get; set; } = new();
}
