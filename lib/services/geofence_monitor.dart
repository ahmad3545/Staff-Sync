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
  });

  final bool enabled;
  final bool isInside;
  final double distanceMeters;
  final DateTime? lastCheck;

  GeofenceSnapshot copyWith({
    bool? enabled,
    bool? isInside,
    double? distanceMeters,
    DateTime? lastCheck,
  }) {
    return GeofenceSnapshot(
      enabled: enabled ?? this.enabled,
      isInside: isInside ?? this.isInside,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      lastCheck: lastCheck ?? this.lastCheck,
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

    _timer?.cancel();
    await _positionSubscription?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _check());
    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen(_handlePosition);
    await _check();
  }

  Future<void> stopMonitoring() async {
    _timer?.cancel();
    _timer = null;
    await _positionSubscription?.cancel();
    _positionSubscription = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefEnabled, false);
    status.value = status.value.copyWith(enabled: false);
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
    status.value = status.value.copyWith(
      enabled: enabled,
      isInside: inside,
      lastCheck: lastCheckMs == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(lastCheckMs),
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

      final isInside = distance <= radius;
      final now = DateTime.now();
      await prefs.setBool(_prefInside, isInside);
      await prefs.setInt(_prefLastCheck, now.millisecondsSinceEpoch);

      status.value = status.value.copyWith(
        enabled: prefs.getBool(_prefEnabled) ?? false,
        isInside: isInside,
        distanceMeters: distance,
        lastCheck: now,
      );

      if (wasInside && !isInside && autoAlerts) {
        await NotificationService.instance.showAlert(
          'Left Site Radius',
          'You are outside the ${radius.toStringAsFixed(0)}m geofence.',
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

  Future<void> _autoCheckout(Position position) async {
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

    final payload = {
      'userId': userId,
      'timestampUtc': DateTime.now().toUtc().toIso8601String(),
      'status': 'check_out',
      'latitude': position.latitude,
      'longitude': position.longitude,
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
