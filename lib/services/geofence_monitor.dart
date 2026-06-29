import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:fyp/constants/app_constants.dart';
import 'package:fyp/services/api_client.dart';
import 'package:fyp/services/auth_service.dart';
import 'package:fyp/services/notification_service.dart';
import 'package:fyp/services/sync_queue_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GeofenceSnapshot {
  GeofenceSnapshot({
    required this.enabled,
    required this.isInside,
    required this.distanceMeters,
    required this.lastCheck,
    this.currentLatitude,
    this.currentLongitude,
  });

  final bool enabled;
  final bool isInside;
  final double distanceMeters;
  final DateTime? lastCheck;
  final double? currentLatitude;
  final double? currentLongitude;

  GeofenceSnapshot copyWith({
    bool? enabled,
    bool? isInside,
    double? distanceMeters,
    DateTime? lastCheck,
    double? currentLatitude,
    double? currentLongitude,
  }) {
    return GeofenceSnapshot(
      enabled: enabled ?? this.enabled,
      isInside: isInside ?? this.isInside,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      lastCheck: lastCheck ?? this.lastCheck,
      currentLatitude: currentLatitude ?? this.currentLatitude,
      currentLongitude: currentLongitude ?? this.currentLongitude,
    );
  }
}

class GeofenceMonitor {
  GeofenceMonitor._();

  static final GeofenceMonitor instance = GeofenceMonitor._();

  static const _prefRadius = 'geofence_radius';
  static const _prefAutoAlerts = 'geofence_auto_alerts';
  static const _prefEnabled = 'geofence_enabled';
  static const _prefInside = 'geofence_inside';
  static const _prefLastCheck = 'geofence_last_check';
  static const _prefDistance = 'geofence_distance_meters';
  static const _prefCurrentLat = 'geofence_current_lat';
  static const _prefCurrentLon = 'geofence_current_lon';
  static const _prefSiteLat = 'geofence_site_lat';
  static const _prefSiteLon = 'geofence_site_lon';
  static const _prefCheckedInPrefix = 'attendance_checked_in_';
  static const _prefLegacyCheckedIn = 'attendance_checked_in';

  final ValueNotifier<GeofenceSnapshot> status = ValueNotifier(
    GeofenceSnapshot(
      enabled: false,
      isInside: true,
      distanceMeters: 0,
      lastCheck: null,
    ),
  );

  Timer? _timer;
  StreamSubscription<Position>? _positionSubscription;
  bool _checking = false;

  Future<void> primeLocationTracking() async {
    await loadSettings();
    final permitted = await _ensurePermission();
    if (!permitted) {
      return;
    }
    await _startPositionUpdates();
    await _check();
  }

  Future<void> checkoutIfNeeded({String reason = 'auto_checkout'}) async {
    final prefs = await SharedPreferences.getInstance();
    final checkedIn = await _isCurrentUserCheckedIn(prefs);
    if (!checkedIn) {
      return;
    }

    Position? position;
    try {
      final permitted = await _ensurePermission();
      if (permitted) {
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
          ),
        );
      }
    } catch (_) {
      // Use saved coordinates if fresh location is unavailable.
    }

    await _checkoutWithPosition(position, reason: reason);
  }

  Future<void> checkoutAndStopForLogout() async {
    await checkoutIfNeeded(reason: 'logout');
    await stopAllTracking();
  }

  Future<void> startMonitoring() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(_prefEnabled) ?? false;
    if (!enabled) {
      return;
    }

    await NotificationService.instance.initialize();
    await NotificationService.instance.requestPermissions();
    final permitted = await _ensurePermission();
    if (!permitted) {
      return;
    }

    await _startPositionUpdates();
    await _check();
  }

  Future<void> stopMonitoring() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefEnabled, false);
    status.value = status.value.copyWith(enabled: false);
  }

  Future<void> stopAllTracking() async {
    _timer?.cancel();
    _timer = null;
    await _positionSubscription?.cancel();
    _positionSubscription = null;
    await stopMonitoring();
  }

  Future<void> _startPositionUpdates() async {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _check());
    if (_positionSubscription != null) {
      return;
    }
    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen(_handlePosition);
  }

  Future<void> updateSettings({
    required double radiusMeters,
    required bool autoAlerts,
    required bool enabled,
    double? siteLatitude,
    double? siteLongitude,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_prefRadius, radiusMeters);
    await prefs.setBool(_prefAutoAlerts, autoAlerts);
    await prefs.setBool(_prefEnabled, enabled);
    if (siteLatitude != null && siteLongitude != null) {
      await prefs.setDouble(_prefSiteLat, siteLatitude);
      await prefs.setDouble(_prefSiteLon, siteLongitude);
    }

    status.value = status.value.copyWith(enabled: enabled);
    final currentLat = prefs.getDouble(_prefCurrentLat);
    final currentLon = prefs.getDouble(_prefCurrentLon);
    if (currentLat != null && currentLon != null) {
      await _recalculateSavedPosition(
        currentLat,
        currentLon,
        radiusMeters,
        siteLatitude ?? prefs.getDouble(_prefSiteLat),
        siteLongitude ?? prefs.getDouble(_prefSiteLon),
      );
    }

    if (enabled) {
      await startMonitoring();
    } else {
      await stopMonitoring();
    }
  }

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(_prefEnabled) ?? false;
    final inside = prefs.getBool(_prefInside) ?? true;
    final lastCheckMs = prefs.getInt(_prefLastCheck);
    final distance = prefs.getDouble(_prefDistance) ?? 0;
    final currentLat = prefs.getDouble(_prefCurrentLat);
    final currentLon = prefs.getDouble(_prefCurrentLon);
    status.value = status.value.copyWith(
      enabled: enabled,
      isInside: inside,
      distanceMeters: distance,
      lastCheck: lastCheckMs == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(lastCheckMs),
      currentLatitude: currentLat,
      currentLongitude: currentLon,
    );
  }

  Future<void> _check() async {
    if (_checking) {
      return;
    }
    _checking = true;

    try {
      final permitted = await _ensurePermission();
      if (!permitted) {
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      await _handlePosition(position);
    } catch (_) {
      // Ignore background errors.
    } finally {
      _checking = false;
    }
  }

  Future<void> _handlePosition(Position position) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final radius = prefs.getDouble(_prefRadius) ?? 120;
      final autoAlerts = prefs.getBool(_prefAutoAlerts) ?? true;
      final wasInside = prefs.getBool(_prefInside) ?? true;
      final siteLat =
          prefs.getDouble(_prefSiteLat) ?? AppConstants.geofenceSiteLat;
      final siteLon =
          prefs.getDouble(_prefSiteLon) ?? AppConstants.geofenceSiteLon;

      final distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        siteLat,
        siteLon,
      );

      final isInside = distance <= _effectiveRadius(radius);
      final now = DateTime.now();
      await prefs.setBool(_prefInside, isInside);
      await prefs.setInt(_prefLastCheck, now.millisecondsSinceEpoch);
      await prefs.setDouble(_prefDistance, distance);
      await prefs.setDouble(_prefCurrentLat, position.latitude);
      await prefs.setDouble(_prefCurrentLon, position.longitude);

      status.value = status.value.copyWith(
        enabled: prefs.getBool(_prefEnabled) ?? false,
        isInside: isInside,
        distanceMeters: distance,
        lastCheck: now,
        currentLatitude: position.latitude,
        currentLongitude: position.longitude,
      );

      final checkedIn = await _isCurrentUserCheckedIn(prefs);
      if (checkedIn && !isInside && autoAlerts) {
        await NotificationService.instance.showAlert(
          'Left Site Radius',
          wasInside
              ? 'You are outside the ${radius.toStringAsFixed(0)}m geofence.'
              : 'You are currently outside the site radius.',
        );
        await _autoCheckout(position);
      }
    } catch (_) {
      // Ignore background errors.
    }
  }

  Future<bool> _ensurePermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    return permission != LocationPermission.denied &&
        permission != LocationPermission.deniedForever;
  }

  Future<void> _recalculateSavedPosition(
    double currentLat,
    double currentLon,
    double radius,
    double? siteLat,
    double? siteLon,
  ) async {
    if (siteLat == null || siteLon == null) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final distance = Geolocator.distanceBetween(
      currentLat,
      currentLon,
      siteLat,
      siteLon,
    );
    final isInside = distance <= _effectiveRadius(radius);
    final now = DateTime.now();
    await prefs.setBool(_prefInside, isInside);
    await prefs.setDouble(_prefDistance, distance);
    await prefs.setInt(_prefLastCheck, now.millisecondsSinceEpoch);
    status.value = status.value.copyWith(
      isInside: isInside,
      distanceMeters: distance,
      lastCheck: now,
      currentLatitude: currentLat,
      currentLongitude: currentLon,
    );
  }

  Future<bool> _isCurrentUserCheckedIn(SharedPreferences prefs) async {
    final auth = AuthService();
    final userId = auth.currentUserId;
    if (userId == null || userId.isEmpty) {
      return false;
    }
    return prefs.getBool('$_prefCheckedInPrefix$userId') ??
        prefs.getBool(_prefLegacyCheckedIn) ??
        false;
  }

  double _effectiveRadius(double radius) => radius < 25 ? 25 : radius;

  Future<void> _autoCheckout(Position position) async {
    await _checkoutWithPosition(position, reason: 'left_site');
  }

  Future<void> _checkoutWithPosition(
    Position? position, {
    required String reason,
  }) async {
    final auth = AuthService();
    final userId = auth.currentUserId;
    if (userId == null || userId.isEmpty) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final checkedIn =
        prefs.getBool('$_prefCheckedInPrefix$userId') ??
        prefs.getBool(_prefLegacyCheckedIn) ??
        false;
    if (!checkedIn) {
      return;
    }

    final latitude = position?.latitude ?? prefs.getDouble(_prefCurrentLat);
    final longitude = position?.longitude ?? prefs.getDouble(_prefCurrentLon);
    final payload = {
      'userId': userId,
      'timestampUtc': DateTime.now().toUtc().toIso8601String(),
      'status': 'check_out',
      'reason': reason,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
    };

    try {
      final response = await ApiClient().postJson(
        '/api/attendance/mark',
        payload,
      );
      if (response.statusCode == 200) {
        await prefs.setBool('$_prefCheckedInPrefix$userId', false);
        await prefs.setBool(_prefLegacyCheckedIn, false);
        await stopMonitoring();
      } else {
        throw Exception('checkout failed');
      }
    } catch (_) {
      await SyncQueueService().enqueue(
        method: 'POST',
        path: '/api/attendance/mark',
        body: payload,
      );
      await prefs.setBool('$_prefCheckedInPrefix$userId', false);
      await prefs.setBool(_prefLegacyCheckedIn, false);
      await stopMonitoring();
    }
  }
}
