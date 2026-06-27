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
  static const _prefCheckedIn = 'attendance_checked_in';

  final ValueNotifier<GeofenceSnapshot> status = ValueNotifier(
    GeofenceSnapshot(
      enabled: false,
      isInside: true,
      distanceMeters: 0,
      lastCheck: null,
    ),
  );

  Timer? _timer;
  bool _checking = false;

  Future<void> startMonitoring() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(_prefEnabled) ?? false;
    if (!enabled) {
      return;
    }

    await NotificationService.instance.initialize();
    await NotificationService.instance.requestPermissions();

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _check());
    await _check();
  }

  Future<void> stopMonitoring() async {
    _timer?.cancel();
    _timer = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefEnabled, false);
    status.value = status.value.copyWith(enabled: false);
  }

  Future<void> updateSettings({
    required double radiusMeters,
    required bool autoAlerts,
    required bool enabled,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_prefRadius, radiusMeters);
    await prefs.setBool(_prefAutoAlerts, autoAlerts);
    await prefs.setBool(_prefEnabled, enabled);

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
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        final requested = await Geolocator.requestPermission();
        if (requested == LocationPermission.denied ||
            requested == LocationPermission.deniedForever) {
          return;
        }
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final prefs = await SharedPreferences.getInstance();
      final radius = prefs.getDouble(_prefRadius) ?? 120;
      final autoAlerts = prefs.getBool(_prefAutoAlerts) ?? true;
      final wasInside = prefs.getBool(_prefInside) ?? true;

      final distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        AppConstants.geofenceSiteLat,
        AppConstants.geofenceSiteLon,
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
        await _autoCheckout();
      }
    } catch (_) {
      // Ignore background errors.
    } finally {
      _checking = false;
    }
  }

  Future<void> _autoCheckout() async {
    final auth = AuthService();
    final userId = auth.currentUserId;
    if (userId == null || userId.isEmpty) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final checkedIn = prefs.getBool(_prefCheckedIn) ?? false;
    if (!checkedIn) {
      return;
    }

    final payload = {
      'userId': userId,
      'timestampUtc': DateTime.now().toUtc().toIso8601String(),
      'status': 'check_out',
    };

    try {
      final response = await ApiClient().postJson(
        '/api/attendance/mark',
        payload,
      );
      if (response.statusCode == 200) {
        await prefs.setBool(_prefCheckedIn, false);
      } else {
        throw Exception('checkout failed');
      }
    } catch (_) {
      await SyncQueueService().enqueue(
        method: 'POST',
        path: '/api/attendance/mark',
        body: payload,
      );
      await prefs.setBool(_prefCheckedIn, false);
    }
  }
}
