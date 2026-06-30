import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:fyp/constants/app_constants.dart';
import 'package:fyp/services/api_client.dart';
import 'package:fyp/services/auth_service.dart';
import 'package:fyp/services/geofence_monitor.dart';
import 'package:fyp/services/user_context.dart';
import 'package:fyp/utils/app_theme.dart';
import 'package:intl/intl.dart';

class ManagerDashboardScreen extends StatefulWidget {
  const ManagerDashboardScreen({super.key});

  @override
  State<ManagerDashboardScreen> createState() => _ManagerDashboardScreenState();
}

class _ManagerDashboardScreenState extends State<ManagerDashboardScreen> {
  final ApiClient _apiClient = ApiClient();
  final AuthService _authService = AuthService();
  final UserContext _userContext = UserContext();

  bool _isLoading = false;
  String _managerName = 'Manager';
  int _totalStaff = 0;
  int _presentToday = 0;
  int _pendingLeaves = 0;
  int _pendingTasks = 0;

  @override
  void initState() {
    super.initState();
    Future(() => GeofenceMonitor.instance.primeLocationTracking());
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    final userId = _userContext.userId;
    if (userId == null || userId.isEmpty) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final results = await Future.wait([
        _apiClient.get('/api/users'),
        _apiClient.get('/api/attendance/summary'),
        _apiClient.get('/api/leave'),
        _apiClient.get('/api/tasks'),
        _apiClient.get('/api/users/$userId'),
      ]);

      final users = _decodeList(results[0]);
      final summary = _decodeObject(results[1]);
      final leaves = _decodeList(results[2]);
      final tasks = _decodeList(results[3]);
      final profile = _decodeObject(results[4]);

      final pendingLeaves = leaves.where((item) {
        final data = item['data'] as Map<String, dynamic>? ?? {};
        return (data['status'] ?? '').toString().toLowerCase() == 'pending';
      }).length;

      final pendingTasks = tasks.where((item) {
        final data = item['data'] as Map<String, dynamic>? ?? {};
        final status = (data['status'] ?? '').toString().toLowerCase();
        return status != 'completed' && status != 'verified';
      }).length;

      if (!mounted) {
        return;
      }
      setState(() {
        _totalStaff = users.length;
        _presentToday = (summary['presentToday'] as num?)?.toInt() ?? 0;
        _pendingLeaves = pendingLeaves;
        _pendingTasks = pendingTasks;
        _managerName =
            profile['fullName']?.toString() ??
            (profile['data'] as Map<String, dynamic>?)?['fullName']?.toString() ??
            userId;
      });
    } catch (_) {
      // Keep dashboard usable if a stat fails.
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  List<Map<String, dynamic>> _decodeList(dynamic response) {
    if (response == null || response.statusCode != 200) {
      return [];
    }
    return List<Map<String, dynamic>>.from(
      jsonDecode(response.body) as List<dynamic>,
    );
  }

  Map<String, dynamic> _decodeObject(dynamic response) {
    if (response == null || response.statusCode != 200) {
      return {};
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    return decoded['data'] as Map<String, dynamic>? ?? decoded;
  }

  Future<void> _logout() async {
    await GeofenceMonitor.instance.checkoutAndStopForLogout();
    await _authService.signOut();
    if (!mounted) {
      return;
    }
    Navigator.pushReplacementNamed(context, AppConstants.loginRoute);
  }

  @override
  Widget build(BuildContext context) {
    final today = DateFormat('EEEE, MMM dd, yyyy').format(DateTime.now());

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manager Dashboard'),
        actions: [
          IconButton(
            onPressed: _loadDashboard,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
          IconButton(
            onPressed: _logout,
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadDashboard,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildWelcomeCard(today),
            const SizedBox(height: 16),
            if (_isLoading) const LinearProgressIndicator(minHeight: 2),
            const SizedBox(height: 12),
            _buildStats(),
            const SizedBox(height: 20),
            Text('Manager Tools', style: AppTheme.heading3),
            const SizedBox(height: 12),
            _buildActionsGrid(),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeCard(String today) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Welcome, $_managerName',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(today, style: const TextStyle(color: Colors.white70)),
          const SizedBox(height: 4),
          const Text(
            'Role: Manager',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildStats() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.7,
      children: [
        _buildStatCard('Staff', '$_totalStaff', Icons.groups, Colors.blue),
        _buildStatCard(
          'Present Today',
          '$_presentToday',
          Icons.fact_check,
          AppTheme.successColor,
        ),
        _buildStatCard(
          'Pending Leaves',
          '$_pendingLeaves',
          Icons.event_busy,
          AppTheme.warningColor,
        ),
        _buildStatCard(
          'Open Tasks',
          '$_pendingTasks',
          Icons.task_alt,
          Colors.purple,
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color.withValues(alpha: 0.12),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    color: color,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(label, style: const TextStyle(fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionsGrid() {
    final actions = [
      _ManagerAction('Assign Tasks', Icons.assignment_add, Colors.purple,
          AppConstants.assignTasksRoute),
      _ManagerAction('Verify Tasks', Icons.verified_outlined, Colors.pink,
          AppConstants.verifyTasksRoute),
      _ManagerAction('Approve Leaves', Icons.event_available, Colors.orange,
          AppConstants.approveLeavesRoute),
      _ManagerAction('Generate Report', Icons.description_outlined,
          Colors.brown, AppConstants.reportsRoute),
      _ManagerAction('View Staff', Icons.groups_outlined, Colors.blue,
          AppConstants.staffManagementRoute),
      _ManagerAction('View Attendance', Icons.list_alt, Colors.deepPurple,
          AppConstants.viewAttendanceRoute),
      _ManagerAction('Mark Attendance', Icons.fact_check_outlined,
          Colors.green, AppConstants.markAttendanceRoute),
      _ManagerAction('Send Notification', Icons.notifications_active,
          Colors.deepOrange, null),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: actions.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.4,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemBuilder: (context, index) {
        final action = actions[index];
        return InkWell(
          onTap: () {
            if (action.route == null) {
              _showBroadcastNotificationDialog();
              return;
            }
            Navigator.pushNamed(context, action.route!);
          },
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: action.color.withValues(alpha: 0.18)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircleAvatar(
                  backgroundColor: action.color.withValues(alpha: 0.12),
                  child: Icon(action.icon, color: action.color),
                ),
                const SizedBox(height: 12),
                Text(
                  action.label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showBroadcastNotificationDialog() async {
    final titleController = TextEditingController();
    final bodyController = TextEditingController();
    var isSending = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Send Notification'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: 'Title'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: bodyController,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Message'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isSending ? null : () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isSending
                  ? null
                  : () async {
                      final title = titleController.text.trim();
                      final body = bodyController.text.trim();
                      if (title.isEmpty || body.isEmpty) {
                        return;
                      }
                      setDialogState(() {
                        isSending = true;
                      });
                      final response = await _apiClient.postJson(
                        '/api/notifications/broadcast',
                        {'title': title, 'body': body, 'type': 'manager'},
                      );
                      if (!mounted) {
                        return;
                      }
                      if (dialogContext.mounted) {
                        Navigator.pop(dialogContext);
                      }
                      if (!context.mounted) {
                        return;
                      }
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            response.statusCode == 200
                                ? 'Notification sent.'
                                : 'Failed: ${response.statusCode}',
                          ),
                        ),
                      );
                    },
              child: Text(isSending ? 'Sending' : 'Send'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ManagerAction {
  const _ManagerAction(this.label, this.icon, this.color, this.route);

  final String label;
  final IconData icon;
  final Color color;
  final String? route;
}
