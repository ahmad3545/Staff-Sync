using System.ComponentModel.DataAnnotations;

namespace StaffSync.Api.Models;

public class GeofenceSettingsUpdate
{
    [Range(-90, 90)]
    public double CenterLatitude { get; set; }

    [Range(-180, 180)]
    public double CenterLongitude { get; set; }

    [Range(10, 10000)]
    public double RadiusMeters { get; set; }
}
