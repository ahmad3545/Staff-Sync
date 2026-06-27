import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fyp/services/api_client.dart';
import 'package:fyp/services/offline_actions.dart';
import 'package:fyp/services/sync_queue_service.dart';
import 'package:fyp/utils/app_theme.dart';

class AssignTasksScreen extends StatefulWidget {
  const AssignTasksScreen({super.key});

  @override
  State<AssignTasksScreen> createState() => _AssignTasksScreenState();
}

class _AssignTasksScreenState extends State<AssignTasksScreen> {
  final _titleController = TextEditingController();
  final _notesController = TextEditingController();
  final _assigneeController = TextEditingController();
  String _selectedPriority = 'Medium';
  final ApiClient _apiClient = ApiClient();
  final SyncQueueService _syncQueue = SyncQueueService();
  final List<Map<String, String>> _assignedTasks = [];
  bool _isLoading = false;
  final List<Map<String, String>> _users = [];
  String? _selectedUserId;
  String? _usersError;

  @override
  void initState() {
    super.initState();
    _loadAssignments();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    _assigneeController.dispose();
    super.dispose();
  }

  Future<void> _assignTask() async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a task title.')),
      );
      return;
    }
    final assigneeId = _selectedUserId ?? _assigneeController.text.trim();
    if (assigneeId.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter a user ID.')));
      return;
    }

    final payload = {
      'userId': assigneeId,
      'title': _titleController.text.trim(),
      'description': _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
      'priority': _selectedPriority.toLowerCase(),
      'dueDateUtc': null,
      'assignedBy': 'Admin',
    };

    try {
      debugPrint('Assigning task to assigneeId=$assigneeId');
      final currentUser = FirebaseAuth.instance.currentUser;
      debugPrint(
        'Current user uid=${currentUser?.uid} email=${currentUser?.email}',
      );

      final taskRef = await FirebaseFirestore.instance.collection('tasks').add({
        ...payload,
        'status': 'assigned',
        'createdAtUtc': FieldValue.serverTimestamp(),
      });
      debugPrint('Created task doc id=${taskRef.id}');

      await FirebaseFirestore.instance.collection('users').doc(assigneeId).set({
        'assignedTasks': FieldValue.arrayUnion([taskRef.id]),
        'updatedAtUtc': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Task saved to Firestore.')));
    } catch (e, st) {
      debugPrint('Firestore assign failed: $e');
      debugPrint('$st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Firestore write failed: ${e.toString()}')),
        );
      }
      try {
        await _apiClient.postJson(OfflineActions.assignTask, payload);
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Task assigned via backend fallback.')),
        );
      } catch (e2, st2) {
        debugPrint('Backend fallback failed: $e2');
        debugPrint('$st2');
        await _syncQueue.enqueue(
          method: 'POST',
          path: OfflineActions.assignTask,
          body: payload,
        );
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Saved offline. Will sync when online.'),
          ),
        );
      }
    }

    _titleController.clear();
    _notesController.clear();
    _assigneeController.clear();
    await _loadAssignments();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Assign Tasks')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('New Task', style: AppTheme.heading3),
          const SizedBox(height: 12),
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: 'Task Title',
              prefixIcon: Icon(Icons.task_alt_outlined),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _selectedUserId,
            isExpanded: true,
            items: _users
                .map(
                  (user) => DropdownMenuItem(
                    value: user['id'],
                    child: Text(
                      user['label'] ?? user['name'] ?? user['id'] ?? 'User',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            selectedItemBuilder: (context) => _users
                .map(
                  (user) => Text(
                    user['label'] ?? user['name'] ?? user['id'] ?? 'User',
                    overflow: TextOverflow.ellipsis,
                  ),
                )
                .toList(),
            onChanged: (value) {
              setState(() {
                _selectedUserId = value;
              });
            },
            decoration: const InputDecoration(
              labelText: 'Assign To (User)',
              prefixIcon: Icon(Icons.person_outline),
            ),
          ),
          if (_users.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('No registered users found.'),
            ),
          if (_usersError != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _usersError!,
                style: const TextStyle(color: AppTheme.warningColor),
              ),
            ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _selectedPriority,
            items: ['Low', 'Medium', 'High']
                .map(
                  (level) => DropdownMenuItem(value: level, child: Text(level)),
                )
                .toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _selectedPriority = value;
                });
              }
            },
            decoration: const InputDecoration(
              labelText: 'Priority',
              prefixIcon: Icon(Icons.flag_outlined),
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
              onPressed: _assignTask,
              icon: const Icon(Icons.send_outlined),
              label: const Text('Assign Task'),
            ),
          ),
          const SizedBox(height: 24),
          Text('Recent Assignments', style: AppTheme.heading3),
          const SizedBox(height: 12),
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else
            ..._assignedTasks.map(
              (task) => Card(
                child: ListTile(
                  title: Text(task['title'] ?? ''),
                  subtitle: Text(
                    '${task['assignee']} • ${task['priority']} priority',
                  ),
                  trailing: Text(task['due'] ?? ''),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _loadAssignments() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final userNames = <String, String>{};
      final userList = <Map<String, String>>[];

      final usersResponse = await _apiClient.get('/api/users');
      if (usersResponse.statusCode == 200) {
        final users = List<Map<String, dynamic>>.from(
          jsonDecode(usersResponse.body) as List<dynamic>,
        );
        for (final user in users) {
          final data = user['data'] as Map<String, dynamic>? ?? {};
          final name = data['fullName']?.toString();
          final email = data['email']?.toString();
          final role = (data['role'] ?? '').toString().toLowerCase();
          final id = user['id']?.toString();
          if (id != null && role != 'admin') {
            final displayName = name == null || name.isEmpty
                ? (email == null || email.isEmpty ? id : email)
                : name;
            userNames[id] = displayName;
            userList.add({
              'id': id,
              'name': displayName,
              'email': email == null || email.isEmpty ? '-' : email,
              'label': email == null || email.isEmpty
                  ? displayName
                  : '$displayName ($email)',
            });
          }
        }
        _usersError = null;
      } else if (usersResponse.statusCode == 401 ||
          usersResponse.statusCode == 403) {
        _usersError = 'Admin access required. Logout/login as admin.';
      } else {
        _usersError =
            'Failed to load users (status ${usersResponse.statusCode}).';
      }

      var tasks = await _loadTasksFromFirestore();
      if (tasks.isEmpty) {
        final tasksResponse = await _apiClient.get('/api/tasks');
        if (tasksResponse.statusCode == 200) {
          tasks = List<Map<String, dynamic>>.from(
            jsonDecode(tasksResponse.body) as List<dynamic>,
          );
        }
      }

      final mapped = <Map<String, String>>[];
      mapped.addAll(
        tasks.map((task) {
          final data = task['data'] as Map<String, dynamic>? ?? {};
          final assigneeId = data['userId']?.toString() ?? '-';
          final dueDate = _formatDate(data['dueDateUtc']);
          return {
            'title': data['title']?.toString() ?? 'Task',
            'assignee': userNames[assigneeId] ?? assigneeId,
            'priority': _labelPriority(data['priority']?.toString()),
            'due': dueDate,
          };
        }),
      );

      setState(() {
        _assignedTasks
          ..clear()
          ..addAll(mapped);
        _users
          ..clear()
          ..addAll(userList);
        if (_selectedUserId == null && userList.isNotEmpty) {
          _selectedUserId = userList.first['id'];
        }
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _usersError = 'Unable to reach server. Check backend/CORS.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<List<Map<String, dynamic>>> _loadTasksFromFirestore() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('tasks')
          .orderBy('createdAtUtc', descending: true)
          .limit(200)
          .get();
      return snapshot.docs
          .map((doc) => {'id': doc.id, 'data': doc.data()})
          .toList();
    } catch (_) {
      return <Map<String, dynamic>>[];
    }
  }

  String _formatDate(dynamic value) {
    if (value is Timestamp) {
      final parsed = value.toDate().toLocal();
      return '${parsed.month}/${parsed.day}';
    }
    if (value is String) {
      final parsed = DateTime.tryParse(value)?.toLocal();
      if (parsed != null) {
        return '${parsed.month}/${parsed.day}';
      }
    }
    return 'TBD';
  }

  String _labelPriority(String? value) {
    switch (value?.toLowerCase()) {
      case 'high':
        return 'High';
      case 'low':
        return 'Low';
      case 'medium':
        return 'Medium';
      default:
        return 'Medium';
    }
  }
}
