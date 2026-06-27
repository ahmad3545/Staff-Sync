import 'package:flutter/material.dart';
import 'package:fyp/constants/app_constants.dart';
import 'package:fyp/utils/app_theme.dart';
import 'dart:async';
import 'package:fyp/services/geofence_monitor.dart';
import 'package:fyp/services/sync_manager.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _startApp();
  }

  Future<void> _startApp() async {
    Future(() async {
      try {
        await SyncManager().syncAll().timeout(const Duration(seconds: 5));
      } catch (_) {
        // Ignore sync errors on boot.
      }
    });

    Future(() async {
      try {
        await GeofenceMonitor.instance.startMonitoring().timeout(
          const Duration(seconds: 5),
        );
      } catch (_) {
        // Ignore geofence errors on boot.
      }
    });

    Timer(const Duration(seconds: 2), () {
      if (!mounted) {
        return;
      }
      Navigator.pushReplacementNamed(context, AppConstants.loginRoute);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primaryColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo Icon (using a placeholder)
            Icon(Icons.people_alt_rounded, size: 120, color: Colors.white),
            const SizedBox(height: 24),

            // App Name
            Text(
              AppConstants.appName,
              style: const TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 8),

            // Tagline
            Text(
              AppConstants.appTagline,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.white70,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 48),

            // Loading Indicator
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}
