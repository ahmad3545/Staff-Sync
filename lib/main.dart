import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:fyp/firebase_options.dart';
import 'package:fyp/constants/app_constants.dart';
import 'package:fyp/utils/app_theme.dart';
import 'package:fyp/screens/splash_screen.dart';
import 'package:fyp/screens/login_screen.dart';
import 'package:fyp/screens/register_screen.dart';
import 'package:fyp/screens/dashboard_screen.dart';
import 'package:fyp/screens/admin_dashboard_screen.dart';
import 'package:fyp/screens/attendance_screen.dart';
import 'package:fyp/screens/schedule_screen.dart';
import 'package:fyp/screens/leave_request_screen.dart';
import 'package:fyp/screens/tasks_screen.dart';
import 'package:fyp/screens/profile_screen.dart';
import 'package:fyp/screens/settings_screen.dart';
import 'package:fyp/screens/geofence_settings_screen.dart';
import 'package:fyp/screens/view_attendance_screen.dart';
import 'package:fyp/screens/notifications_screen.dart';
import 'package:fyp/screens/reports_screen.dart';
import 'package:fyp/screens/payroll_screen.dart';
import 'package:fyp/screens/staff_management_screen.dart';
import 'package:fyp/screens/shift_management_screen.dart';
import 'package:fyp/screens/mark_attendance_screen.dart';
import 'package:fyp/screens/approve_leaves_screen.dart';
import 'package:fyp/screens/assign_tasks_screen.dart';
import 'package:fyp/screens/verify_tasks_screen.dart';
import 'package:fyp/screens/departments_screen.dart';
import 'package:fyp/screens/system_settings_screen.dart';
import 'package:fyp/screens/forgot_password_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      initialRoute: AppConstants.splashRoute,
      routes: {
        AppConstants.splashRoute: (context) => const SplashScreen(),
        AppConstants.loginRoute: (context) => const LoginScreen(),
        AppConstants.registerRoute: (context) => const RegisterScreen(),
        AppConstants.dashboardRoute: (context) => const DashboardScreen(),
        '/admin-dashboard': (context) => const AdminDashboardScreen(),
        AppConstants.attendanceRoute: (context) => const AttendanceScreen(),
        AppConstants.scheduleRoute: (context) => const ScheduleScreen(),
        AppConstants.leaveRequestRoute: (context) => const LeaveRequestScreen(),
        AppConstants.tasksRoute: (context) => const TasksScreen(),
        AppConstants.profileRoute: (context) => const ProfileScreen(),
        AppConstants.settingsRoute: (context) => const SettingsScreen(),
        AppConstants.geofenceSettingsRoute: (context) =>
            const GeofenceSettingsScreen(),
        AppConstants.viewAttendanceRoute: (context) =>
            const ViewAttendanceScreen(),
        AppConstants.notificationsRoute: (context) =>
            const NotificationsScreen(),
        AppConstants.reportsRoute: (context) => const ReportsScreen(),
        AppConstants.payrollRoute: (context) => const PayrollScreen(),
        AppConstants.staffManagementRoute: (context) =>
            const StaffManagementScreen(),
        AppConstants.shiftManagementRoute: (context) =>
            const ShiftManagementScreen(),
        AppConstants.markAttendanceRoute: (context) =>
            const MarkAttendanceScreen(),
        AppConstants.approveLeavesRoute: (context) =>
            const ApproveLeavesScreen(),
        AppConstants.assignTasksRoute: (context) => const AssignTasksScreen(),
        AppConstants.verifyTasksRoute: (context) => const VerifyTasksScreen(),
        AppConstants.departmentsRoute: (context) => const DepartmentsScreen(),
        AppConstants.systemSettingsRoute: (context) =>
            const SystemSettingsScreen(),
        AppConstants.forgotPasswordRoute: (context) =>
            const ForgotPasswordScreen(),
      },
    );
  }
}
