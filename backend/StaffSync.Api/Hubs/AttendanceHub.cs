using Microsoft.AspNetCore.SignalR;

namespace StaffSync.Api.Hubs;

public class AttendanceHub : Hub
{
    public async Task BroadcastAttendanceUpdate(string userId, object payload)
    {
        await Clients.All.SendAsync("attendanceUpdated", userId, payload);
    }
}
