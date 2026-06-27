import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:fyp/constants/app_constants.dart';
import 'package:fyp/services/api_client.dart';
import 'package:fyp/services/user_context.dart';
import '../utils/app_theme.dart';
import 'package:intl/intl.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final ApiClient _apiClient = ApiClient();
  final UserContext _userContext = UserContext();
  bool _isLoading = false;

  String _adminName = 'Admin';
  String _adminRole = 'Administrator';
  String _todayLabel = '';
  int _totalStaff = 0;
  int _presentToday = 0;
  int _pendingLeaves = 0;
  int _pendingTasks = 0;
  int _lateArrivals = 0;
  int _activeShifts = 0;
  final List<Map<String, dynamic>> _recentActivities = [];

  @override
  void initState() {
    super.initState();
    _todayLabel = DateFormat('EEEE, MMM dd, yyyy').format(DateTime.now());
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
        _apiClient.get('/api/shifts'),
        _apiClient.get('/api/attendance/recent', query: {'limit': '20'}),
        _apiClient.get('/api/users/$userId'),
      ]);

      final users = _decodeList(results[0]);
      final summary = _decodeObject(results[1]);
      final leaves = _decodeList(results[2]);
      final tasks = _decodeList(results[3]);
      final shifts = _decodeList(results[4]);
      final attendanceRecent = _decodeList(results[5]);
      final profile = _decodeObject(results[6]);

      final userNames = <String, String>{};
      for (final user in users) {
        final data = user['data'] as Map<String, dynamic>? ?? {};
        final id = user['id']?.toString();
        final name = data['fullName']?.toString();
        if (id != null) {
          userNames[id] = name == null || name.isEmpty ? id : name;
        }
      }

      final pendingLeaves = leaves.where((item) {
        final data = item['data'] as Map<String, dynamic>? ?? {};
        return (data['status'] ?? '').toString().toLowerCase() == 'pending';
      }).length;

      final pendingTasks = tasks.where((item) {
        final data = item['data'] as Map<String, dynamic>? ?? {};
        final status = (data['status'] ?? '').toString().toLowerCase();
        return status != 'completed' && status != 'verified';
      }).length;

      final activeShifts = shifts.where((item) {
        final data = item['data'] as Map<String, dynamic>? ?? {};
        final status = (data['status'] ?? '').toString().toLowerCase();
        return status.isEmpty || status == 'active';
      }).length;

      final recent = _buildRecentActivityItems(
        attendanceRecent,
        leaves,
        tasks,
        userNames,
      );

      final profileData = profile['data'] as Map<String, dynamic>? ?? {};
      final profileName = profileData['fullName']?.toString();
      final profileRole = profileData['role']?.toString();

      setState(() {
        _totalStaff = users.length;
        _presentToday = (summary['presentToday'] as num?)?.toInt() ?? 0;
        _pendingLeaves = pendingLeaves;
        _pendingTasks = pendingTasks;
        _lateArrivals = 0;
        _activeShifts = activeShifts;
        _recentActivities
          ..clear()
          ..addAll(recent);
        _adminName = profileName != null && profileName.isNotEmpty
            ? profileName
            : userId;
        _adminRole = profileRole != null && profileRole.isNotEmpty
            ? profileRole
            : 'Administrator';
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
    return Map<String, dynamic>.from(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  List<Map<String, dynamic>> _buildRecentActivityItems(
    List<Map<String, dynamic>> attendance,
    List<Map<String, dynamic>> leaves,
    List<Map<String, dynamic>> tasks,
    Map<String, String> userNames,
  ) {
    final items = <Map<String, dynamic>>[];

    for (final entry in attendance) {
      final data = entry['data'] as Map<String, dynamic>? ?? {};
      final userId = data['userId']?.toString() ?? '-';
      final status = (data['status'] ?? 'present').toString();
      final action = status == 'check_out' ? 'Checked out' : 'Checked in';
      final time = _parseDate(data['timestampUtc']);
      items.add({
        'user': userNames[userId] ?? userId,
        'action': action,
        'time': time,
        'icon': status == 'check_out' ? Icons.logout : Icons.login,
        'color': status == 'check_out' ? Colors.orange : Colors.green,
      });
    }

    for (final entry in leaves) {
      final data = entry['data'] as Map<String, dynamic>? ?? {};
      final userId = data['userId']?.toString() ?? '-';
      final status = (data['status'] ?? 'pending').toString();
      final time = _parseDate(data['createdAtUtc']);
      items.add({
        'user': userNames[userId] ?? userId,
        'action': status == 'pending' ? 'Requested leave' : 'Leave $status',
        'time': time,
        'icon': Icons.event_busy,
        'color': Colors.orange,
      });
    }

    for (final entry in tasks) {
      final data = entry['data'] as Map<String, dynamic>? ?? {};
      final userId = data['userId']?.toString() ?? '-';
      final title = data['title']?.toString() ?? 'Task';
      final time = _parseDate(data['createdAtUtc']);
      items.add({
        'user': userNames[userId] ?? userId,
        'action': 'Assigned: $title',
        'time': time,
        'icon': Icons.task_alt,
        'color': Colors.purple,
      });
    }

    items.sort((a, b) {
      final aTime = a['time'] as DateTime?;
      final bTime = b['time'] as DateTime?;
      if (aTime == null && bTime == null) return 0;
      if (aTime == null) return 1;
      if (bTime == null) return -1;
      return bTime.compareTo(aTime);
    });

    return items.take(6).toList();
  }

  DateTime? _parseDate(dynamic value) {
    if (value is String) {
      return DateTime.tryParse(value)?.toLocal();
    }
    return null;
  }

  String _formatRelative(DateTime? value) {
    if (value == null) {
      return '-';
    }
    final diff = DateTime.now().difference(value);
    if (diff.inMinutes < 1) {
      return 'just now';
    }
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes} mins ago';
    }
    if (diff.inHours < 24) {
      return '${diff.inHours} hrs ago';
    }
    return '${diff.inDays} days ago';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppTheme.primaryColor,
        title: const Text(
          'Admin Dashboard',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined, color: Colors.white),
            onPressed: () {
              Navigator.pushNamed(context, AppConstants.notificationsRoute);
            },
          ),
          IconButton(
            icon: const Icon(Icons.campaign_outlined, color: Colors.white),
            tooltip: 'Send notification to all employees',
            onPressed: _showBroadcastNotificationDialog,
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: Colors.white),
            onPressed: () {
              Navigator.pushNamed(context, AppConstants.systemSettingsRoute);
            },
          ),
        ],
      ),
      drawer: _buildDrawer(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_isLoading) const LinearProgressIndicator(minHeight: 2),
            _buildWelcomeCard(),
            const SizedBox(height: 16),
            _buildBroadcastPromptCard(),
            const SizedBox(height: 20),
            _buildStatisticsCards(),
            const SizedBox(height: 24),
            const Text(
              'Admin Controls',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            _buildAdminActionsGrid(),
            const SizedBox(height: 24),
            const Text(
              'Quick Stats',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            _buildQuickStats(),
            const SizedBox(height: 24),
            const Text(
              'Recent Activities',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            _buildRecentActivities(),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryColor,
            AppTheme.primaryColor.withOpacity(0.7),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 35,
            backgroundColor: Colors.white,
            child: Text(
              'AD',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryColor,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome back, $_adminName!',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _todayLabel,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _adminRole,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBroadcastPromptCard() {
    return InkWell(
      onTap: _showBroadcastNotificationDialog,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.deepOrange.shade400, Colors.deepOrange.shade700],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.deepOrange.withOpacity(0.25),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.campaign_outlined,
                color: Colors.white,
                size: 28,
              ),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Send Notification to All Employees',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Tap here to write and broadcast a message to everyone.',
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildStatisticsCards() {
    final attendanceRate = _totalStaff == 0
        ? 0
        : ((_presentToday / _totalStaff) * 100).round();
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Total Staff',
            '$_totalStaff',
            Icons.people,
            Colors.blue,
            'Updated today',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'Present Today',
            '$_presentToday',
            Icons.check_circle,
            Colors.green,
            '$attendanceRate% attendance',
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
    String subtitle,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color, size: 28),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '↑',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(fontSize: 11, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminActionsGrid() {
    final actions = [
      {
        'icon': FontAwesomeIcons.usersCog,
        'label': 'Manage Staff',
        'color': Colors.blue,
        'route': AppConstants.staffManagementRoute,
      },
      {
        'icon': FontAwesomeIcons.clipboardCheck,
        'label': 'Mark Attendance',
        'color': Colors.green,
        'route': AppConstants.markAttendanceRoute,
      },
      {
        'icon': FontAwesomeIcons.clipboardList,
        'label': 'View Attendance',
        'color': Colors.deepPurple,
        'route': AppConstants.viewAttendanceRoute,
      },
      {
        'icon': FontAwesomeIcons.fileCircleCheck,
        'label': 'Approve Leaves',
        'color': Colors.orange,
        'route': AppConstants.approveLeavesRoute,
      },
      {
        'icon': FontAwesomeIcons.tasks,
        'label': 'Assign Tasks',
        'color': Colors.purple,
        'route': AppConstants.assignTasksRoute,
      },
      {
        'icon': FontAwesomeIcons.clipboardCheck,
        'label': 'Verify Tasks',
        'color': Colors.pink,
        'route': AppConstants.verifyTasksRoute,
      },
      {
        'icon': FontAwesomeIcons.chartLine,
        'label': 'View Reports',
        'color': Colors.teal,
        'route': AppConstants.reportsRoute,
      },
      {
        'icon': FontAwesomeIcons.calendarDays,
        'label': 'Manage Shifts',
        'color': Colors.indigo,
        'route': AppConstants.shiftManagementRoute,
      },
      {
        'icon': FontAwesomeIcons.locationDot,
        'label': 'Geofence Settings',
        'color': Colors.blueAccent,
        'route': AppConstants.geofenceSettingsRoute,
      },
      {
        'icon': FontAwesomeIcons.building,
        'label': 'Departments',
        'color': Colors.cyan,
        'route': AppConstants.departmentsRoute,
      },
      {
        'icon': FontAwesomeIcons.moneyBillWave,
        'label': 'Manage Payroll',
        'color': Colors.amber,
        'route': AppConstants.payrollRoute,
      },
      {
        'icon': FontAwesomeIcons.bell,
        'label': 'Send Notifications',
        'color': Colors.deepOrange,
        'route': null,
      },
      {
        'icon': FontAwesomeIcons.fileLines,
        'label': 'Generate Report',
        'color': Colors.brown,
        'route': AppConstants.reportsRoute,
      },
      {
        'icon': FontAwesomeIcons.gear,
        'label': 'System Settings',
        'color': Colors.blueGrey,
        'route': AppConstants.systemSettingsRoute,
      },
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.5,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: actions.length,
      itemBuilder: (context, index) {
        final action = actions[index];
        return _buildActionCard(
          action['icon'] as IconData,
          action['label'] as String,
          action['color'] as Color,
          route: action['route'] as String?,
          onTap: action['label'] == 'Send Notifications'
              ? _showBroadcastNotificationDialog
              : null,
        );
      },
    );
  }

  Widget _buildActionCard(
    IconData icon,
    String label,
    Color color, {
    String? route,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: () {
        if (onTap != null) {
          onTap();
          return;
        }
        if (route != null) {
          Navigator.pushNamed(context, route);
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$label - Coming in Phase-II'),
            duration: const Duration(seconds: 2),
          ),
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: FaIcon(icon, size: 32, color: color),
            ),
            const SizedBox(height: 12),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showBroadcastNotificationDialog() async {
    final titleController = TextEditingController();
    final bodyController = TextEditingController();
    String selectedType = 'info';
    bool isSending = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Send Notification to All Employees'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        labelText: 'Title',
                        hintText: 'e.g. Office meeting at 3 PM',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: bodyController,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Message',
                        hintText: 'Write notification message here',
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: selectedType,
                      decoration: const InputDecoration(labelText: 'Type'),
                      items: const [
                        DropdownMenuItem(value: 'info', child: Text('Info')),
                        DropdownMenuItem(
                          value: 'success',
                          child: Text('Success'),
                        ),
                        DropdownMenuItem(
                          value: 'warning',
                          child: Text('Warning'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setDialogState(() {
                          selectedType = value;
                        });
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSending
                      ? null
                      : () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                ElevatedButton.icon(
                  onPressed: isSending
                      ? null
                      : () async {
                          final title = titleController.text.trim();
                          final body = bodyController.text.trim();
                          if (title.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Title is required'),
                              ),
                            );
                            return;
                          }

                          setDialogState(() {
                            isSending = true;
                          });

                          try {
                            final response = await _apiClient.postJson(
                              '/api/notifications/broadcast',
                              {
                                'title': title,
                                'body': body,
                                'type': selectedType,
                              },
                            );

                            if (!mounted) return;

                            if (response.statusCode == 200) {
                              Navigator.pop(dialogContext);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Notification sent to all employees',
                                  ),
                                ),
                              );
                            } else {
                              setDialogState(() {
                                isSending = false;
                              });
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Failed to send notification: ${response.statusCode}',
                                  ),
                                ),
                              );
                            }
                          } catch (e) {
                            if (!mounted) return;
                            setDialogState(() {
                              isSending = false;
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error sending notification: $e'),
                              ),
                            );
                          }
                        },
                  icon: isSending
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send),
                  label: Text(isSending ? 'Sending' : 'Send'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildQuickStats() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildStatRow(
            'Pending Leave Requests',
            '$_pendingLeaves',
            Colors.orange,
          ),
          const Divider(height: 24),
          _buildStatRow('Pending Tasks', '$_pendingTasks', Colors.purple),
          const Divider(height: 24),
          _buildStatRow('Late Arrivals Today', '$_lateArrivals', Colors.red),
          const Divider(height: 24),
          _buildStatRow('Active Shifts', '$_activeShifts', Colors.blue),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black87,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRecentActivities() {
    return Column(
      children: _recentActivities.isEmpty
          ? [
              Text(
                'No recent activity yet.',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ]
          : _recentActivities
                .map(
                  (activity) => Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: (activity['color'] as Color).withOpacity(
                              0.1,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            activity['icon'] as IconData,
                            color: activity['color'] as Color,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${activity['user']} ${activity['action']}',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _formatRelative(activity['time'] as DateTime?),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.primaryColor,
                  AppTheme.primaryColor.withOpacity(0.7),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const CircleAvatar(
                  radius: 35,
                  backgroundColor: Colors.white,
                  child: Text(
                    'AD',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Administrator',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'admin@staffsync.com',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.dashboard, color: Colors.blue),
            title: const Text('Dashboard'),
            onTap: () => Navigator.pop(context),
          ),
          ListTile(
            leading: const Icon(Icons.people, color: Colors.green),
            title: const Text('Staff Management'),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, AppConstants.staffManagementRoute);
            },
          ),
          ListTile(
            leading: const Icon(Icons.calendar_today, color: Colors.orange),
            title: const Text('Attendance Records'),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, AppConstants.viewAttendanceRoute);
            },
          ),
          ListTile(
            leading: const Icon(Icons.event_note, color: Colors.purple),
            title: const Text('Leave Approvals'),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, AppConstants.approveLeavesRoute);
            },
          ),
          ListTile(
            leading: const Icon(Icons.assignment, color: Colors.teal),
            title: const Text('Task Management'),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, AppConstants.assignTasksRoute);
            },
          ),
          ListTile(
            leading: const Icon(Icons.bar_chart, color: Colors.indigo),
            title: const Text('Reports & Analytics'),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, AppConstants.reportsRoute);
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.settings, color: Colors.grey),
            title: const Text('Settings'),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, AppConstants.systemSettingsRoute);
            },
          ),
          ListTile(
            leading: const Icon(Icons.help_outline, color: Colors.grey),
            title: const Text('Help & Support'),
            onTap: () {
              Navigator.pop(context);
              showDialog<void>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Help & Support'),
                  content: const Text(
                    'For assistance, contact support@staffsync.com.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('OK'),
                    ),
                  ],
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Logout'),
            onTap: () {
              Navigator.pushReplacementNamed(context, '/login');
            },
          ),
        ],
      ),
    );
  }
}
