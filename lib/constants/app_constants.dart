import 'package:flutter/foundation.dart';

class AppConstants {
  // App Info
  static const String appName = 'StaffSync';
  static const String appVersion = '1.0.0';
  static const String appTagline = 'Smart Workforce Management';

  // Routes
  static const String splashRoute = '/';
  static const String loginRoute = '/login';
  static const String registerRoute = '/register';
  static const String dashboardRoute = '/dashboard';
  static const String attendanceRoute = '/attendance';
  static const String scheduleRoute = '/schedule';
  static const String leaveRequestRoute = '/leave-request';
  static const String tasksRoute = '/tasks';
  static const String profileRoute = '/profile';
  static const String settingsRoute = '/settings';
  static const String geofenceSettingsRoute = '/geofence-settings';
  static const String viewAttendanceRoute = '/view-attendance';
  static const String notificationsRoute = '/notifications';
  static const String reportsRoute = '/reports';
  static const String absentPredictionRoute = '/absent-prediction';
  static const String payrollRoute = '/payroll';
  static const String staffManagementRoute = '/staff-management';
  static const String shiftManagementRoute = '/shift-management';
  static const String markAttendanceRoute = '/mark-attendance';
  static const String approveLeavesRoute = '/approve-leaves';
  static const String assignTasksRoute = '/assign-tasks';
  static const String verifyTasksRoute = '/verify-tasks';
  static const String departmentsRoute = '/departments';
  static const String systemSettingsRoute = '/system-settings';
  static const String forgotPasswordRoute = '/forgot-password';

  // Dummy User Data
  static const String dummyUserName = 'Ahmed Raza';
  static const String dummyUserEmail = 'ahmed@staffsync.com';
  static const String dummyUserPhone = '+92 300 1234567';
  static const String dummyEmployeeId = 'EMP-001';
  static const String dummyDepartment = 'IT Development';
  static const String dummyRole = 'Employee';

  // Leave Types
  static const List<String> leaveTypes = [
    'Casual Leave',
    'Sick Leave',
    'Annual Leave',
    'Emergency Leave',
    'Unpaid Leave',
  ];

  // Roles
  static const List<String> roles = [
    'Admin',
    'Manager',
    'Employee',
    'Field Staff',
  ];

  // Shift Types
  static const String morningShift = 'Morning Shift';
  static const String eveningShift = 'Evening Shift';
  static const String nightShift = 'Night Shift';

  // Geofence defaults
  static const double geofenceSiteLat = 31.4704;
  static const double geofenceSiteLon = 74.2724;
  static const double geofenceDefaultRadius = 120;
  static const String geofenceSiteName = 'Main Office';
  static const String geofenceSiteAddress = 'Gulberg, Lahore';

  // API
  static String get apiBaseUrl {
    if (kIsWeb) {
      return 'http://localhost:5108';
    }
    return 'http://10.0.2.2:5108';
  }
}
