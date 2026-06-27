import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:fyp/services/api_client.dart';
import 'package:fyp/services/user_context.dart';
import 'package:fyp/utils/app_theme.dart';
import 'package:intl/intl.dart';

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  String _selectedFilter = 'all';
  bool _isLoading = false;
  final List<Map<String, dynamic>> _tasks = [];
  final ApiClient _apiClient = ApiClient();
  final UserContext _userContext = UserContext();

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  List<Map<String, dynamic>> _getFilteredTasks() {
    if (_selectedFilter == 'all') {
      return _tasks;
    }
    return _tasks.where((task) => task['status'] == _selectedFilter).toList();
  }

  Color _getPriorityColor(String priority) {
    switch (priority) {
      case 'high':
        return AppTheme.errorColor;
      case 'medium':
        return AppTheme.warningColor;
      case 'low':
        return AppTheme.successColor;
      default:
        return Colors.grey;
    }
  }

  IconData _getPriorityIcon(String priority) {
    switch (priority) {
      case 'high':
        return Icons.priority_high;
      case 'medium':
        return Icons.remove;
      case 'low':
        return Icons.arrow_downward;
      default:
        return Icons.circle;
    }
  }

  void _showTaskDetails(Map<String, dynamic> task) {
    final attachments = <String>[];
    final notesController = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(task['title'], style: AppTheme.heading2),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Chip(
                          avatar: Icon(
                            _getPriorityIcon(task['priority']),
                            color: Colors.white,
                            size: 16,
                          ),
                          label: Text(
                            '${task['priority'].toString().toUpperCase()} PRIORITY',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                          backgroundColor: _getPriorityColor(task['priority']),
                        ),
                        const SizedBox(width: 8),
                        Chip(
                          label: Text(
                            task['status'].toString().toUpperCase(),
                            style: const TextStyle(fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text('Description', style: AppTheme.heading3),
                    const SizedBox(height: 8),
                    Text(task['description'], style: AppTheme.bodyMedium),
                    const SizedBox(height: 16),
                    _buildDetailRow(
                      Icons.calendar_today,
                      'Due Date',
                      '${task['dueDate']} at ${task['dueTime']}',
                    ),
                    _buildDetailRow(
                      Icons.person,
                      'Assigned By',
                      task['assignedBy'],
                    ),
                    _buildDetailRow(
                      Icons.location_on,
                      'Location',
                      task['location'],
                    ),
                    const SizedBox(height: 24),
                    Text('Task Proof', style: AppTheme.heading3),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              setModalState(() {
                                attachments.add(
                                  'Camera_${attachments.length + 1}.jpg',
                                );
                              });
                            },
                            icon: const Icon(Icons.camera_alt),
                            label: const Text('Camera'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              setModalState(() {
                                attachments.add(
                                  'Gallery_${attachments.length + 1}.jpg',
                                );
                              });
                            },
                            icon: const Icon(Icons.photo_library),
                            label: const Text('Gallery'),
                          ),
                        ),
                      ],
                    ),
                    if (attachments.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: attachments
                            .map(
                              (file) => Chip(
                                label: Text(file),
                                onDeleted: () {
                                  setModalState(() {
                                    attachments.remove(file);
                                  });
                                },
                              ),
                            )
                            .toList(),
                      ),
                    ],
                    const SizedBox(height: 16),
                    TextField(
                      controller: notesController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Add Notes',
                        hintText: 'Enter completion notes...',
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (task['status'] != 'completed')
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: () => _markTaskAsComplete(
                            context,
                            task['id'],
                            notesController.text,
                          ),
                          child: const Text(
                            'MARK AS COMPLETE',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _markTaskAsComplete(
    BuildContext context,
    String taskId,
    String notes,
  ) async {
    // Show a loading indicator and pop the bottom sheet
    Navigator.pop(context);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Submitting task...')));

    try {
      await FirebaseFirestore.instance.collection('tasks').doc(taskId).update({
        'status': 'completed',
        'completionNotes': notes,
        'completedAtUtc': FieldValue.serverTimestamp(),
      });

      // Refresh the tasks list
      _loadTasks();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Task marked as complete!'),
          backgroundColor: AppTheme.successColor,
        ),
      );
    } catch (e) {
      debugPrint('Error marking task as complete: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to update task. Please try again.'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppTheme.textSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTheme.bodySmall),
                Text(value, style: AppTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredTasks = _getFilteredTasks();
    final totalTasks = _tasks.length;
    final pendingTasks = _tasks
        .where((task) => task['status'] == 'pending')
        .length;
    final completedTasks = _tasks
        .where((task) => task['status'] == 'completed')
        .length;

    return Scaffold(
      appBar: AppBar(title: const Text('Tasks')),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    '$totalTasks',
                    'Total',
                    AppTheme.primaryColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    '$pendingTasks',
                    'Pending',
                    AppTheme.warningColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    '$completedTasks',
                    'Done',
                    AppTheme.successColor,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    label: const Center(child: Text('All')),
                    selected: _selectedFilter == 'all',
                    onSelected: (selected) {
                      if (selected) setState(() => _selectedFilter = 'all');
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ChoiceChip(
                    label: const Center(child: Text('Pending')),
                    selected: _selectedFilter == 'pending',
                    onSelected: (selected) {
                      if (selected) setState(() => _selectedFilter = 'pending');
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ChoiceChip(
                    label: const Center(child: Text('In Progress')),
                    selected: _selectedFilter == 'in-progress',
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => _selectedFilter = 'in-progress');
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ChoiceChip(
                    label: const Center(child: Text('Done')),
                    selected: _selectedFilter == 'completed',
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => _selectedFilter = 'completed');
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredTasks.length,
                    itemBuilder: (context, index) {
                      final task = filteredTasks[index];
                      final priorityColor = _getPriorityColor(task['priority']);

                      return Card(
                        child: ListTile(
                          leading: Container(
                            width: 4,
                            height: 60,
                            decoration: BoxDecoration(
                              color: priorityColor,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          title: Text(
                            task['title'],
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(
                                    _getPriorityIcon(task['priority']),
                                    size: 14,
                                    color: priorityColor,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${task['priority'].toString().toUpperCase()} Priority',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: priorityColor,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Due: ${task['dueDate']}, ${task['dueTime']}',
                              ),
                            ],
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.arrow_forward_ios, size: 16),
                            onPressed: () => _showTaskDetails(task),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 12, color: color)),
        ],
      ),
    );
  }

  Future<void> _loadTasks() async {
    final userId = _userContext.userId;
    debugPrint('[TasksScreen] Loading tasks for userId: $userId');
    if (userId == null || userId.isEmpty) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      debugPrint('[TasksScreen] Trying to load tasks from Firestore...');
      final firestoreTasks = await _loadTasksFromFirestore(userId);
      debugPrint(
        '[TasksScreen] Loaded ${firestoreTasks.length} tasks from Firestore.',
      );

      final source = firestoreTasks.isNotEmpty
          ? firestoreTasks
          : await _loadTasksFromApi(userId);
      if (firestoreTasks.isEmpty) {
        debugPrint(
          '[TasksScreen] Firestore was empty, loaded ${source.length} tasks from API fallback.',
        );
      }
      final mapped = source.map((item) {
        final data = item['data'] as Map<String, dynamic>? ?? {};
        final dueDate = _parseDate(data['dueDateUtc']);
        final rawStatus = (data['status'] ?? 'assigned').toString();
        final normalizedStatus = rawStatus == 'assigned'
            ? 'pending'
            : rawStatus.toLowerCase();
        final priority = (data['priority'] ?? 'medium').toString();
        return {
          'id': item['id'],
          'title': data['title'] ?? 'Task',
          'description': data['description'] ?? '-',
          'dueDate': dueDate == null
              ? '-'
              : DateFormat('MMM dd, yyyy').format(dueDate),
          'dueTime': dueDate == null
              ? '-'
              : DateFormat('hh:mm a').format(dueDate),
          'priority': priority.toLowerCase(),
          'assignedBy': data['assignedBy'] ?? 'Admin',
          'location': data['location'] ?? '-',
          'status': normalizedStatus,
        };
      }).toList();
      debugPrint('[TasksScreen] Mapped ${mapped.length} tasks for UI.');

      setState(() {
        _tasks
          ..clear()
          ..addAll(mapped);
      });
    } catch (e, st) {
      debugPrint('[TasksScreen] Error loading tasks: $e');
      debugPrint('$st');
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
    if (value == null) {
      return null;
    }
    if (value is Timestamp) {
      return value.toDate().toLocal();
    }
    if (value is String) {
      return DateTime.tryParse(value)?.toLocal();
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> _loadTasksFromFirestore(
    String userId,
  ) async {
    try {
      debugPrint('[TasksScreen-Firestore] Fetching user doc: users/$userId');
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      if (!userDoc.exists) {
        debugPrint('[TasksScreen-Firestore] User doc users/$userId not found.');
        return <Map<String, dynamic>>[];
      }

      final data = userDoc.data() ?? <String, dynamic>{};
      debugPrint('[TasksScreen-Firestore] User data: $data');
      final rawTaskIds = data['assignedTasks'] ?? data['taskIds'];
      if (rawTaskIds is! List || rawTaskIds.isEmpty) {
        debugPrint(
          '[TasksScreen-Firestore] assignedTasks/taskIds field is missing, not a list, or empty.',
        );
        return <Map<String, dynamic>>[];
      }
      debugPrint(
        '[TasksScreen-Firestore] Found task IDs: ${rawTaskIds.join(', ')}',
      );

      final taskIds = rawTaskIds
          .map((id) => id?.toString())
          .whereType<String>()
          .where((id) => id.isNotEmpty)
          .toList();
      if (taskIds.isEmpty) {
        debugPrint(
          '[TasksScreen-Firestore] No valid task IDs found after filtering.',
        );
        return <Map<String, dynamic>>[];
      }

      debugPrint(
        '[TasksScreen-Firestore] Fetching ${taskIds.length} task documents.',
      );
      final snapshots = await Future.wait(
        taskIds.map(
          (id) => FirebaseFirestore.instance.collection('tasks').doc(id).get(),
        ),
      );

      final tasks = snapshots
          .where((doc) => doc.exists)
          .map((doc) => {'id': doc.id, 'data': doc.data() ?? {}})
          .toList();

      debugPrint(
        '[TasksScreen-Firestore] Found ${tasks.length} existing task documents.',
      );

      tasks.sort((a, b) {
        final aDate = _parseDate(
          (a['data'] as Map<String, dynamic>)['createdAtUtc'],
        );
        final bDate = _parseDate(
          (b['data'] as Map<String, dynamic>)['createdAtUtc'],
        );
        if (aDate == null && bDate == null) {
          return 0;
        }
        if (aDate == null) {
          return 1;
        }
        if (bDate == null) {
          return -1;
        }
        return bDate.compareTo(aDate);
      });

      return tasks;
    } catch (e, st) {
      debugPrint('[TasksScreen-Firestore] Error: $e');
      debugPrint('$st');
      return <Map<String, dynamic>>[];
    }
  }

  Future<List<Map<String, dynamic>>> _loadTasksFromApi(String userId) async {
    try {
      final response = await _apiClient.get('/api/tasks/$userId');
      if (response.statusCode != 200) {
        debugPrint(
          '[TasksScreen-API] Failed to load tasks, status: ${response.statusCode}',
        );
        return <Map<String, dynamic>>[];
      }
      final tasks = List<Map<String, dynamic>>.from(
        jsonDecode(response.body) as List<dynamic>,
      );
      debugPrint('[TasksScreen-API] Loaded ${tasks.length} tasks from API.');
      return tasks;
    } catch (e, st) {
      debugPrint('[TasksScreen-API] Error: $e');
      debugPrint('$st');
      return <Map<String, dynamic>>[];
    }
  }
}
