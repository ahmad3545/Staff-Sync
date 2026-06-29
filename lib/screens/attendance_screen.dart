import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fyp/utils/app_theme.dart';
import 'package:fyp/constants/app_constants.dart';
import 'package:fyp/services/api_client.dart';
import 'package:fyp/services/geofence_monitor.dart';
import 'package:fyp/services/offline_actions.dart';
import 'package:fyp/services/sync_queue_service.dart';
import 'package:fyp/services/user_context.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  static const String _prefAttendanceCachePrefix = 'attendance_cache_';
  static const String _prefAttendanceCheckedInPrefix = 'attendance_checked_in_';
  bool isCheckedIn = false;
  String currentTime = '';
  String currentDate = '';
  String _userName = 'User';
  String _siteName = AppConstants.geofenceSiteName;
  String _siteAddress = AppConstants.geofenceSiteAddress;
  double _siteLat = AppConstants.geofenceSiteLat;
  double _siteLon = AppConstants.geofenceSiteLon;
  double _geofenceRadius = AppConstants.geofenceDefaultRadius;
  double? _currentLat;
  double? _currentLon;
  double? _distanceMeters;
  bool? _isInsideSite;
  bool _isLoading = false;
  final List<Map<String, dynamic>> _attendanceList = [];
  final ApiClient _apiClient = ApiClient();
  final UserContext _userContext = UserContext();
  final SyncQueueService _syncQueue = SyncQueueService();

  @override
  void initState() {
    super.initState();
    _updateTime();
    _loadProfileAndSiteDetails();
    _loadAttendance();
    _refreshLocationStatus();
  }

  void _updateTime() {
    final now = DateTime.now();
    setState(() {
      currentDate = DateFormat('EEEE, MMM dd, yyyy').format(now);
      currentTime = DateFormat('hh:mm a').format(now);
    });
  }

  Future<void> _handleCheckInOut() async {
    final userId = _userContext.userId;
    if (userId == null || userId.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please login first.')));
      return;
    }

    final nextStatus = isCheckedIn ? 'check_out' : 'check_in';
    Position? position;
    if (nextStatus == 'check_in') {
      position = await _refreshLocationStatus();
      if (_isInsideSite != true) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'You are outside $_siteName. Distance: ${_formatDistance(_distanceMeters)}',
            ),
            backgroundColor: AppTheme.errorColor,
          ),
        );
        return;
      }
    } else {
      position = await _getCurrentPosition();
    }

    final payload = {
      'userId': userId,
      'timestampUtc': DateTime.now().toUtc().toIso8601String(),
      'status': nextStatus,
      if (position != null) 'latitude': position.latitude,
      if (position != null) 'longitude': position.longitude,
    };

    try {
      final response = await _apiClient.postJson(
        OfflineActions.markAttendance,
        payload,
      );

      if (response.statusCode == 401 || response.statusCode == 403) {
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Authentication failed. Please login again.'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
        return;
      }

      if (response.statusCode != 200) {
        throw Exception(
          'Attendance update failed (${response.statusCode}): ${response.body}',
        );
      }

      setState(() {
        isCheckedIn = !isCheckedIn;
      });
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_attendanceCheckedInKey(userId), isCheckedIn);
      await _syncGeofencingWithCheckIn(isCheckedIn);
      await _loadAttendance();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isCheckedIn
                ? 'Checked In Successfully!'
                : 'Checked Out Successfully!',
          ),
          backgroundColor: AppTheme.successColor,
        ),
      );
    } catch (error) {
      debugPrint('Attendance error: $error');
      await _syncQueue.enqueue(
        method: 'POST',
        path: OfflineActions.markAttendance,
        body: payload,
      );
      setState(() {
        isCheckedIn = !isCheckedIn;
        _attendanceList.insert(0, {
          'id': 'local-${DateTime.now().millisecondsSinceEpoch}',
          'data': {
            'status': nextStatus,
            'timestampUtc': payload['timestampUtc'],
          },
        });
      });
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_attendanceCheckedInKey(userId), isCheckedIn);
      await _syncGeofencingWithCheckIn(isCheckedIn);
      await _cacheAttendance(_attendanceList, userId);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Saved offline. Will sync when online.'),
          backgroundColor: AppTheme.warningColor,
        ),
      );
    }
  }

  Future<void> _loadAttendance() async {
    final userId = _userContext.userId;
    if (userId == null || userId.isEmpty) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      return;
    }

    setState(() {
      _isLoading = true;
      _attendanceList.clear();
    });

    try {
      final response = await _apiClient.get('/api/attendance/$userId');
      if (response.statusCode == 200) {
        final list = response.body.isEmpty
            ? <dynamic>[]
            : jsonDecode(response.body) as List<dynamic>;
        final records = List<Map<String, dynamic>>.from(
          list.map((item) => item as Map<String, dynamic>),
        );
        _attendanceList
          ..clear()
          ..addAll(records);

        if (_attendanceList.isNotEmpty) {
          final latest = _attendanceList.first;
          final status = (latest['data']?['status'] ?? '').toString();
          setState(() {
            isCheckedIn = status == 'check_in';
          });
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool(_attendanceCheckedInKey(userId), isCheckedIn);
          await _syncGeofencingWithCheckIn(isCheckedIn);
        }

        await _cacheAttendance(_attendanceList, userId);
      } else {
        await _loadAttendanceFromCache(userId);
      }
    } catch (_) {
      await _loadAttendanceFromCache(userId);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _cacheAttendance(
    List<Map<String, dynamic>> list,
    String userId,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_attendanceCacheKey(userId), jsonEncode(list));
  }

  Future<void> _loadAttendanceFromCache(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_attendanceCacheKey(userId));
    if (raw == null || raw.isEmpty) {
      return;
    }

    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      return;
    }

    final cached = List<Map<String, dynamic>>.from(decoded);
    if (!mounted) {
      return;
    }

    setState(() {
      _attendanceList
        ..clear()
        ..addAll(cached);
    });

    if (_attendanceList.isNotEmpty) {
      final latest = _attendanceList.first;
      final status = (latest['data']?['status'] ?? '').toString();
      setState(() {
        isCheckedIn = status == 'check_in';
      });
      await _syncGeofencingWithCheckIn(isCheckedIn);
    }
  }

  String _attendanceCacheKey(String userId) =>
      '$_prefAttendanceCachePrefix$userId';
  String _attendanceCheckedInKey(String userId) =>
      '$_prefAttendanceCheckedInPrefix$userId';

  Future<void> _syncGeofencingWithCheckIn(bool checkedIn) async {
    final prefs = await SharedPreferences.getInstance();
    final radius =
        prefs.getDouble('geofence_radius') ??
        AppConstants.geofenceDefaultRadius;
    final autoAlerts = prefs.getBool('geofence_auto_alerts') ?? true;
    final siteLat = prefs.getDouble('geofence_site_lat') ?? _siteLat;
    final siteLon = prefs.getDouble('geofence_site_lon') ?? _siteLon;

    await GeofenceMonitor.instance.updateSettings(
      radiusMeters: radius,
      autoAlerts: autoAlerts,
      enabled: checkedIn,
      siteLatitude: siteLat,
      siteLongitude: siteLon,
    );
  }

  Future<void> _loadProfileAndSiteDetails() async {
    final prefs = await SharedPreferences.getInstance();
    await _loadServerGeofence(prefs);
    final siteName = prefs.getString('geofence_site_name');
    final siteAddress = prefs.getString('geofence_site_address');
    final siteLat =
        prefs.getDouble('geofence_site_lat') ?? AppConstants.geofenceSiteLat;
    final siteLon =
        prefs.getDouble('geofence_site_lon') ?? AppConstants.geofenceSiteLon;
    final radius =
        prefs.getDouble('geofence_radius') ??
        AppConstants.geofenceDefaultRadius;
    if (mounted) {
      setState(() {
        _siteName = (siteName == null || siteName.isEmpty)
            ? AppConstants.geofenceSiteName
            : siteName;
        _siteAddress = (siteAddress == null || siteAddress.isEmpty)
            ? AppConstants.geofenceSiteAddress
            : siteAddress;
        _siteLat = siteLat;
        _siteLon = siteLon;
        _geofenceRadius = radius;
      });
    }

    final userId = _userContext.userId;
    if (userId == null || userId.isEmpty) {
      return;
    }

    try {
      final response = await _apiClient.get('/api/users/$userId');
      if (response.statusCode != 200) {
        return;
      }
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final data = decoded['data'] as Map<String, dynamic>? ?? {};
      final fullName = data['fullName']?.toString().trim();
      if (mounted && fullName != null && fullName.isNotEmpty) {
        setState(() {
          _userName = fullName;
        });
      }
    } catch (_) {
      // Ignore profile load errors.
    }
  }

  String _buildSiteLabel() {
    final name = _siteName.trim();
    final address = _siteAddress.trim();
    if (name.isEmpty && address.isEmpty) {
      return 'Location not set';
    }
    if (address.isEmpty) {
      return name;
    }
    if (name.isEmpty) {
      return address;
    }
    return '$name, $address';
  }

  Future<void> _loadServerGeofence(SharedPreferences prefs) async {
    try {
      final response = await _apiClient.get('/api/geofence');
      if (response.statusCode != 200 || response.body.isEmpty) {
        return;
      }
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (decoded['exists'] != true || decoded['data'] is! Map) {
        return;
      }
      final data = Map<String, dynamic>.from(decoded['data'] as Map);
      final siteName = data['siteName']?.toString();
      final siteAddress = data['siteAddress']?.toString();
      final lat = _toDouble(data['centerLatitude']);
      final lon = _toDouble(data['centerLongitude']);
      final radius = _toDouble(data['radiusMeters']);
      if (siteName != null && siteName.isNotEmpty) {
        await prefs.setString('geofence_site_name', siteName);
      }
      if (siteAddress != null && siteAddress.isNotEmpty) {
        await prefs.setString('geofence_site_address', siteAddress);
      }
      if (lat != null && lon != null) {
        await prefs.setDouble('geofence_site_lat', lat);
        await prefs.setDouble('geofence_site_lon', lon);
      }
      if (radius != null) {
        await prefs.setDouble('geofence_radius', radius);
      }
    } catch (_) {
      // Use local/default geofence when the server is unavailable.
    }
  }

  Future<Position?> _refreshLocationStatus() async {
    final position = await _getCurrentPosition();
    if (position == null) {
      if (mounted) {
        setState(() {
          _isInsideSite = null;
          _distanceMeters = null;
        });
      }
      return null;
    }

    final distance = Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      _siteLat,
      _siteLon,
    );
    if (mounted) {
      setState(() {
        _currentLat = position.latitude;
        _currentLon = position.longitude;
        _distanceMeters = distance;
        _isInsideSite = distance <= _geofenceRadius;
      });
    }
    return position;
  }

  Future<Position?> _getCurrentPosition() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return null;
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return null;
    }
    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
  }

  double? _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value?.toString() ?? '');
  }

  String _formatDistance(double? value) {
    if (value == null) {
      return '-';
    }
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(2)} km';
    }
    return '${value.toStringAsFixed(0)} m';
  }

  Widget _buildLocationStatusCard() {
    final inside = _isInsideSite;
    final color = inside == true
        ? AppTheme.successColor
        : inside == false
        ? AppTheme.errorColor
        : AppTheme.warningColor;
    final label = inside == true
        ? 'You are on site'
        : inside == false
        ? 'You are outside site'
        : 'Location not checked';

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.location_on_outlined, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(fontWeight: FontWeight.bold, color: color),
                ),
              ),
              TextButton.icon(
                onPressed: _refreshLocationStatus,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Refresh'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _buildSiteLabel(),
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            'Distance from site: ${_formatDistance(_distanceMeters)} / ${_geofenceRadius.toStringAsFixed(0)} m radius',
            style: TextStyle(fontSize: 12, color: Colors.grey[700]),
          ),
          if (_currentLat != null && _currentLon != null) ...[
            const SizedBox(height: 4),
            Text(
              'Your coordinates: ${_currentLat!.toStringAsFixed(6)}, ${_currentLon!.toStringAsFixed(6)}',
              style: TextStyle(fontSize: 12, color: Colors.grey[700]),
            ),
          ],
          const SizedBox(height: 4),
          Text(
            'Site coordinates: ${_siteLat.toStringAsFixed(6)}, ${_siteLon.toStringAsFixed(6)}',
            style: TextStyle(fontSize: 12, color: Colors.grey[700]),
          ),
        ],
      ),
    );
  }

  void _showCameraDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Take Selfie'),
        content: const Text(
          'Camera feature will be implemented with actual camera integration',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showQRScanner() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('QR Code Scanner'),
        content: const Text(
          'QR Scanner will be implemented with actual camera integration',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  DateTime? _parseDate(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is Timestamp) {
      return value.toDate().toLocal();
    }
    if (value is DateTime) {
      return value.toLocal();
    }
    if (value is String) {
      return DateTime.tryParse(value)?.toLocal();
    }
    if (value is Map<String, dynamic>) {
      if (value.containsKey('_seconds') && value.containsKey('_nanoseconds')) {
        final seconds = value['_seconds'];
        final nanos = value['_nanoseconds'];
        if (seconds is int && nanos is int) {
          return DateTime.fromMillisecondsSinceEpoch(
            seconds * 1000 + (nanos / 1000000).round(),
            isUtc: true,
          ).toLocal();
        }
      }
      if (value.containsKey('seconds') && value.containsKey('nanos')) {
        final seconds = value['seconds'];
        final nanos = value['nanos'];
        if (seconds is int && nanos is int) {
          return DateTime.fromMillisecondsSinceEpoch(
            seconds * 1000 + (nanos / 1000000).round(),
            isUtc: true,
          ).toLocal();
        }
      }
    }
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value, isUtc: true).toLocal();
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final attendanceList = _attendanceList;

    return Scaffold(
      appBar: AppBar(title: const Text('Attendance')),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Current Status Card
            Container(
              width: double.infinity,
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    isCheckedIn ? AppTheme.successColor : AppTheme.primaryColor,
                    isCheckedIn
                        ? Colors.green.shade700
                        : AppTheme.secondaryColor,
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Text(
                    'Welcome, $_userName',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    currentDate,
                    style: const TextStyle(fontSize: 16, color: Colors.white70),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    currentTime,
                    style: const TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    isCheckedIn
                        ? 'Status: Checked In'
                        : 'Status: Ready to Check In',
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.location_on, color: Colors.white70, size: 18),
                      SizedBox(width: 4),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _buildSiteLabel(),
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ),
            ),

            _buildLocationStatusCard(),
            const SizedBox(height: 16),

            // Check In/Out Button
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: 200,
                height: 200,
                child: ElevatedButton(
                  onPressed: _handleCheckInOut,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isCheckedIn
                        ? AppTheme.errorColor
                        : AppTheme.successColor,
                    shape: const CircleBorder(),
                    elevation: 8,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        isCheckedIn ? Icons.logout : Icons.login,
                        size: 48,
                        color: Colors.white,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        isCheckedIn ? 'CHECK\nOUT' : 'CHECK\nIN',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Camera & QR Options
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _showCameraDialog,
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('Take Selfie'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.all(12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _showQRScanner,
                      icon: const Icon(Icons.qr_code_scanner),
                      label: const Text('Scan QR'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.all(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Attendance History
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Attendance History', style: AppTheme.heading3),
                      TextButton(
                        onPressed: () {},
                        child: const Text('View All'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_isLoading)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: attendanceList.length,
                      itemBuilder: (context, index) {
                        final record = attendanceList[index];
                        final data =
                            record['data'] as Map<String, dynamic>? ?? {};
                        final status = (data['status'] ?? 'present').toString();
                        final isPresent =
                            status == 'present' || status == 'check_in';
                        final timestamp = _parseDate(data['timestampUtc']);
                        final dateText = timestamp == null
                            ? '-'
                            : DateFormat('MMM dd, yyyy').format(timestamp);
                        final timeText = timestamp == null
                            ? '-'
                            : DateFormat('hh:mm a').format(timestamp);

                        return Card(
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: isPresent
                                  ? AppTheme.successColor.withValues(alpha: 0.1)
                                  : AppTheme.errorColor.withValues(alpha: 0.1),
                              child: Icon(
                                isPresent ? Icons.check_circle : Icons.cancel,
                                color: isPresent
                                    ? AppTheme.successColor
                                    : AppTheme.errorColor,
                              ),
                            ),
                            title: Text(
                              dateText,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              '$timeText • ${data['status'] ?? '-'}',
                              style: AppTheme.bodySmall,
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
