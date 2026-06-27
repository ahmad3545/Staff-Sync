import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:fyp/constants/app_constants.dart';
import 'package:fyp/services/auth_service.dart';
import 'package:fyp/services/api_client.dart';
import 'package:fyp/services/user_context.dart';
import 'package:fyp/utils/app_theme.dart';
import 'package:intl/intl.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;
  bool _isLoading = false;
  int _presentDays = 0;
  int _totalShifts = 0;
  int _totalLeaves = 0;
  int _pendingTasks = 0;
  int _notificationCount = 0;
  String _userName = 'User';
  String _userEmail = '-';
  String _userRole = '-';
  final List<Map<String, dynamic>> _recentActivity = [];
  final ApiClient _apiClient = ApiClient();
  final UserContext _userContext = UserContext();
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _loadOverview();
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });

    // Navigate based on bottom nav selection
    switch (index) {
      case 0:
        // Already on Home
        break;
      case 1:
        Navigator.pushNamed(context, AppConstants.attendanceRoute);
        break;
      case 2:
        Navigator.pushNamed(context, AppConstants.scheduleRoute);
        break;
      case 3:
        Navigator.pushNamed(context, AppConstants.profileRoute);
        break;
      case 4:
        Navigator.pushNamed(context, AppConstants.settingsRoute);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppConstants.appName),
        actions: [
          IconButton(
            icon: _notificationCount > 0
                ? Badge(
                    label: Text('$_notificationCount'),
                    child: const Icon(Icons.notifications_outlined),
                  )
                : const Icon(Icons.notifications_outlined),
            onPressed: () {
              Navigator.pushNamed(context, AppConstants.notificationsRoute);
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            UserAccountsDrawerHeader(
              decoration: const BoxDecoration(color: AppTheme.primaryColor),
              accountName: Text(_userName),
              accountEmail: Text(_userEmail),
              currentAccountPicture: const CircleAvatar(
                backgroundColor: Colors.white,
                child: Icon(
                  Icons.person,
                  size: 50,
                  color: AppTheme.primaryColor,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.home),
              title: const Text('Home'),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('Profile'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, AppConstants.profileRoute);
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Settings'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, AppConstants.settingsRoute);
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Logout', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pushReplacementNamed(
                  context,
                  AppConstants.loginRoute,
                );
              },
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppTheme.primaryColor, AppTheme.secondaryColor],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome, $_userName!',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _formatToday(),
                    style: const TextStyle(fontSize: 14, color: Colors.white70),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _userRole,
                    style: const TextStyle(fontSize: 14, color: Colors.white70),
                  ),
                ],
              ),
            ),

            // Stats Cards
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_isLoading) const LinearProgressIndicator(minHeight: 2),
                  Text('Overview', style: AppTheme.heading3),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          '$_presentDays/30',
                          'Days Present',
                          Icons.check_circle,
                          AppTheme.successColor,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          '$_totalShifts',
                          'Shifts',
                          Icons.schedule,
                          AppTheme.primaryColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          '$_totalLeaves',
                          'Leaves',
                          Icons.beach_access,
                          AppTheme.warningColor,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          '$_pendingTasks',
                          'Tasks',
                          Icons.task_alt,
                          AppTheme.accentColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Quick Actions
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Quick Actions', style: AppTheme.heading3),
                  const SizedBox(height: 12),
                  GridView.count(
                    crossAxisCount: 3,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    children: [
                      _buildActionCard(
                        'Mark\nAttendance',
                        Icons.fingerprint,
                        AppTheme.successColor,
                        () => Navigator.pushNamed(
                          context,
                          AppConstants.attendanceRoute,
                        ),
                      ),
                      _buildActionCard(
                        'View\nSchedule',
                        Icons.calendar_month,
                        AppTheme.primaryColor,
                        () => Navigator.pushNamed(
                          context,
                          AppConstants.scheduleRoute,
                        ),
                      ),
                      _buildActionCard(
                        'Request\nLeave',
                        Icons.beach_access,
                        AppTheme.warningColor,
                        () => Navigator.pushNamed(
                          context,
                          AppConstants.leaveRequestRoute,
                        ),
                      ),
                      _buildActionCard(
                        'My\nTasks',
                        Icons.task,
                        AppTheme.accentColor,
                        () => Navigator.pushNamed(
                          context,
                          AppConstants.tasksRoute,
                        ),
                      ),
                      _buildActionCard(
                        'View\nPayroll',
                        Icons.payment,
                        Colors.green,
                        () => Navigator.pushNamed(
                          context,
                          AppConstants.payrollRoute,
                        ),
                      ),
                      _buildActionCard(
                        'Submit\nReport',
                        Icons.report,
                        Colors.purple,
                        () => Navigator.pushNamed(
                          context,
                          AppConstants.reportsRoute,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Recent Activity
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Recent Activity', style: AppTheme.heading3),
                  const SizedBox(height: 12),
                  if (_recentActivity.isEmpty)
                    const Text(
                      'No recent activity yet.',
                      style: TextStyle(fontSize: 12, color: Colors.black54),
                    )
                  else
                    ..._recentActivity.map(
                      (item) => _buildActivityItem(
                        item['title']?.toString() ?? '-',
                        item['time']?.toString() ?? '-',
                        item['icon'] as IconData? ?? Icons.info_outline,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppTheme.primaryColor,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(
            icon: Icon(Icons.fingerprint),
            label: 'Attendance',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_month),
            label: 'Schedule',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String value,
    String label,
    IconData icon,
    Color color,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(label, style: AppTheme.bodySmall, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard(
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 32),
              const SizedBox(height: 8),
              Text(
                label,
                style: const TextStyle(fontSize: 11),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActivityItem(String title, String time, IconData icon) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
          child: Icon(icon, color: AppTheme.primaryColor, size: 20),
        ),
        title: Text(title, style: AppTheme.bodyMedium),
        subtitle: Text(time, style: AppTheme.bodySmall),
      ),
    );
  }

  Future<void> _loadOverview() async {
    final userId = _userContext.userId;
    if (userId == null || userId.isEmpty) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final currentUser = _authService.currentUser;
      final results = await Future.wait([
        _apiClient.get('/api/attendance/$userId'),
        _apiClient.get('/api/leave/$userId'),
        _apiClient.get('/api/tasks/$userId'),
        _apiClient.get('/api/shifts'),
        _apiClient.get('/api/users/$userId'),
        _apiClient.get('/api/notifications/$userId'),
      ]);

      final attendance = _decodeList(results[0]);
      final leaves = _decodeList(results[1]);
      final tasks = _decodeList(results[2]);
      final shifts = _decodeList(results[3]);
      final profile = _decodeObject(results[4]);
      final notifications = _decodeList(results[5]);

      final presentDays = attendance
          .map((item) => item['data'] as Map<String, dynamic>? ?? {})
          .where((data) {
            final status = (data['status'] ?? '').toString();
            return status == 'present' || status == 'check_in';
          })
          .length;

      final pendingTasks = tasks
          .map((item) => item['data'] as Map<String, dynamic>? ?? {})
          .where((data) => (data['status'] ?? '') != 'completed')
          .length;

      final recentActivity = _buildRecentActivity(attendance, leaves, tasks);

      setState(() {
        _presentDays = presentDays;
        _totalLeaves = leaves.length;
        _pendingTasks = pendingTasks;
        _totalShifts = shifts.length;
        _notificationCount = notifications.length;
        _userName = profile['fullName']?.toString().trim().isNotEmpty == true
            ? profile['fullName'].toString()
            : (currentUser?.displayName?.trim().isNotEmpty == true
                  ? currentUser!.displayName!
                  : (currentUser?.email?.trim().isNotEmpty == true
                        ? currentUser!.email!
                        : userId));
        _userEmail = profile['email']?.toString().isNotEmpty == true
            ? profile['email'].toString()
            : (currentUser?.email?.trim().isNotEmpty == true
                  ? currentUser!.email!
                  : userId);
        _userRole = profile['role']?.toString().isNotEmpty == true
            ? profile['role'].toString()
            : 'Employee';
        _recentActivity
          ..clear()
          ..addAll(recentActivity);
      });
    } catch (_) {
      // Ignore load errors.
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  List<Map<String, dynamic>> _decodeList(dynamic response) {
    if (response == null) {
      return [];
    }
    if (response.statusCode != 200) {
      return [];
    }
    return List<Map<String, dynamic>>.from(
      jsonDecode(response.body) as List<dynamic>,
    );
  }

  Map<String, dynamic> _decodeObject(dynamic response) {
    if (response == null) {
      return {};
    }
    if (response.statusCode != 200) {
      return {};
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    return decoded['data'] as Map<String, dynamic>? ?? {};
  }

  List<Map<String, dynamic>> _buildRecentActivity(
    List<Map<String, dynamic>> attendance,
    List<Map<String, dynamic>> leaves,
    List<Map<String, dynamic>> tasks,
  ) {
    final items = <Map<String, dynamic>>[];

    for (final item in attendance.take(3)) {
      final data = item['data'] as Map<String, dynamic>? ?? {};
      final status = (data['status'] ?? 'attendance').toString();
      final timestamp = _parseDateTime(data['timestampUtc']);
      items.add({
        'title': 'Attendance ${status.replaceAll('_', ' ')}',
        'time': _formatDateTime(timestamp),
        'timestamp': timestamp,
        'icon': Icons.login,
      });
    }

    for (final item in leaves.take(3)) {
      final data = item['data'] as Map<String, dynamic>? ?? {};
      final timestamp = _parseDateTime(data['createdAtUtc']);
      items.add({
        'title': 'Leave ${data['status'] ?? 'pending'}',
        'time': _formatDateTime(timestamp),
        'timestamp': timestamp,
        'icon': Icons.beach_access,
      });
    }

    for (final item in tasks.take(3)) {
      final data = item['data'] as Map<String, dynamic>? ?? {};
      final timestamp = _parseDateTime(data['createdAtUtc']);
      items.add({
        'title': 'Task ${data['status'] ?? 'updated'}',
        'time': _formatDateTime(timestamp),
        'timestamp': timestamp,
        'icon': Icons.task_alt,
      });
    }

    items.sort((a, b) {
      final aTime = a['timestamp'] as DateTime?;
      final bTime = b['timestamp'] as DateTime?;
      if (aTime == null && bTime == null) {
        return 0;
      }
      if (aTime == null) {
        return 1;
      }
      if (bTime == null) {
        return -1;
      }
      return bTime.compareTo(aTime);
    });
    return items.take(4).toList();
  }

  String _formatToday() {
    return DateFormat('EEEE, MMM dd, yyyy').format(DateTime.now());
  }

  DateTime? _parseDateTime(dynamic value) {
    if (value is String) {
      return DateTime.tryParse(value)?.toLocal();
    }
    return null;
  }

  String _formatDateTime(DateTime? value) {
    if (value == null) {
      return '-';
    }
    return DateFormat('MMM dd, hh:mm a').format(value);
  }
}
