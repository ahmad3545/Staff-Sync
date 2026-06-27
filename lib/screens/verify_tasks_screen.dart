import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:fyp/services/api_client.dart';
import 'package:fyp/services/offline_actions.dart';
import 'package:fyp/services/sync_queue_service.dart';
import 'package:fyp/services/user_context.dart';
import 'package:fyp/utils/app_theme.dart';
import 'package:intl/intl.dart';

class VerifyTasksScreen extends StatefulWidget {
  const VerifyTasksScreen({super.key});

  @override
  State<VerifyTasksScreen> createState() => _VerifyTasksScreenState();
}

class _VerifyTasksScreenState extends State<VerifyTasksScreen> {
  final _taskIdController = TextEditingController();
  final _notesController = TextEditingController();
  String _selectedStatus = 'verified';
  final ApiClient _apiClient = ApiClient();
  final SyncQueueService _syncQueue = SyncQueueService();
  final UserContext _userContext = UserContext();
  final List<Map<String, dynamic>> _tasks = [];
  final Map<String, String> _userNames = {};
  bool _isLoading = false;

  @override
  void dispose() {
    _taskIdController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<void> _verifyTask() async {
    if (_taskIdController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter a task ID.')));
      return;
    }

    await _submitVerification(
      taskId: _taskIdController.text.trim(),
      status: _selectedStatus,
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
    );

    _taskIdController.clear();
    _notesController.clear();
  }

  Future<void> _loadTasks() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final results = await Future.wait([
        _apiClient.get('/api/tasks'),
        _apiClient.get('/api/users'),
      ]);

      if (results[1].statusCode == 200) {
        final users = List<Map<String, dynamic>>.from(
          jsonDecode(results[1].body) as List<dynamic>,
        );
        _userNames
          ..clear()
          ..addEntries(
            users.map((user) {
              final data = user['data'] as Map<String, dynamic>? ?? {};
              final name = data['fullName']?.toString();
              final id = user['id']?.toString() ?? '-';
              return MapEntry(id, name == null || name.isEmpty ? id : name);
            }),
          );
      }

      if (results[0].statusCode == 200) {
        final tasks = List<Map<String, dynamic>>.from(
          jsonDecode(results[0].body) as List<dynamic>,
        );
        final mapped = tasks
            .map((task) {
              final data = task['data'] as Map<String, dynamic>? ?? {};
              final createdAt = _parseDate(data['createdAtUtc']);
              final userId = data['userId']?.toString() ?? '-';
              return {
                'id': task['id']?.toString() ?? '',
                'title': data['title']?.toString() ?? 'Task',
                'userId': userId,
                'assignee': _userNames[userId] ?? userId,
                'status': (data['status'] ?? 'assigned').toString(),
                'createdAt': createdAt,
                'completionNotes': data['completionNotes']?.toString(),
              };
            })
            .where((task) => task['status'] == 'completed')
            .toList();

        setState(() {
          _tasks
            ..clear()
            ..addAll(mapped);
        });
      }
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

  DateTime? _parseDate(dynamic value) {
    if (value is String) {
      return DateTime.tryParse(value)?.toLocal();
    }
    return null;
  }

  String _formatDate(DateTime? value) {
    if (value == null) {
      return '-';
    }
    return DateFormat('MMM dd, yyyy').format(value);
  }

  Future<void> _openVerifyDialog(Map<String, dynamic> task) async {
    final notesController = TextEditingController();
    final completionNotes = task['completionNotes'] as String?;
    var status = 'verified';

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Verify Task'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              task['title']?.toString() ?? 'Task',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            if (completionNotes != null && completionNotes.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('Employee Notes:', style: AppTheme.bodySmall),
              Text(completionNotes),
            ],
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: status,
              items: const [
                DropdownMenuItem(value: 'verified', child: Text('Approved')),
                DropdownMenuItem(
                  value: 'changes_requested',
                  child: Text('Changes Requested'),
                ),
                DropdownMenuItem(value: 'rejected', child: Text('Rejected')),
              ],
              onChanged: (value) {
                if (value != null) {
                  status = value;
                }
              },
              decoration: const InputDecoration(labelText: 'Status'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: notesController,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Notes (optional)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Submit'),
          ),
        ],
      ),
    );

    if (result != true) {
      return;
    }

    await _submitVerification(
      taskId: task['id']?.toString() ?? '',
      status: status,
      notes: notesController.text.trim().isEmpty
          ? null
          : notesController.text.trim(),
    );
  }

  Future<void> _submitVerification({
    required String taskId,
    required String status,
    String? notes,
  }) async {
    if (taskId.isEmpty) {
      return;
    }

    final payload = {
      'taskId': taskId,
      'status': status,
      'reviewerId': _userContext.userId,
      'notes': notes,
    };

    try {
      await _apiClient.postJson(OfflineActions.verifyTask, payload);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Task verification submitted.'),
          backgroundColor: AppTheme.successColor,
        ),
      );
      await _loadTasks();
    } catch (_) {
      await _syncQueue.enqueue(
        method: 'POST',
        path: OfflineActions.verifyTask,
        body: payload,
      );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verify Tasks')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Assigned Tasks', style: AppTheme.heading3),
          const SizedBox(height: 12),
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else if (_tasks.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32.0),
                child: Text(
                  'No tasks are awaiting verification.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else
            ..._tasks.map(
              (task) => Card(
                child: ListTile(
                  title: Text(task['title']?.toString() ?? 'Task'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${task['assignee']} • ${_formatDate(task['createdAt'] as DateTime?)}',
                      ),
                      if (task['completionNotes'] != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Notes: ${task['completionNotes']}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTheme.bodySmall,
                        ),
                      ],
                    ],
                  ),
                  trailing: TextButton(
                    onPressed: () => _openVerifyDialog(task),
                    child: const Text('Verify'),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 24),
          Text('Manual Verification', style: AppTheme.heading3),
          const SizedBox(height: 12),
          TextField(
            controller: _taskIdController,
            decoration: const InputDecoration(
              labelText: 'Task ID',
              prefixIcon: Icon(Icons.task_alt_outlined),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _selectedStatus,
            items: const [
              DropdownMenuItem(value: 'verified', child: Text('Verified')),
              DropdownMenuItem(
                value: 'changes_requested',
                child: Text('Changes Requested'),
              ),
              DropdownMenuItem(value: 'rejected', child: Text('Rejected')),
            ],
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _selectedStatus = value;
                });
              }
            },
            decoration: const InputDecoration(
              labelText: 'Status',
              prefixIcon: Icon(Icons.verified_outlined),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notesController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Notes (optional)',
              alignLabelWithHint: true,
              prefixIcon: Icon(Icons.notes_outlined),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _verifyTask,
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('Submit Verification'),
            ),
          ),
        ],
      ),
    );
  }
}
