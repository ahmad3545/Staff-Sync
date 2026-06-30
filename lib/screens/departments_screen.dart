import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:fyp/services/api_client.dart';
import 'package:fyp/services/offline_actions.dart';
import 'package:fyp/services/sync_queue_service.dart';
import 'package:fyp/utils/app_theme.dart';

class DepartmentsScreen extends StatefulWidget {
  const DepartmentsScreen({super.key});

  @override
  State<DepartmentsScreen> createState() => _DepartmentsScreenState();
}

class _DepartmentsScreenState extends State<DepartmentsScreen> {
  final List<Map<String, dynamic>> _departments = [];
  final List<Map<String, dynamic>> _users = [];
  final List<Map<String, dynamic>> _managers = [];
  bool _isLoading = false;
  final ApiClient _apiClient = ApiClient();
  final SyncQueueService _syncQueue = SyncQueueService();

  @override
  void initState() {
    super.initState();
    _loadDepartments();
  }

  void _addDepartment() {
    final controller = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Department'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Department name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isEmpty) {
                return;
              }
              Navigator.pop(context);
              _submitDepartment(controller.text.trim());
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _submitDepartment(String name) async {
    final payload = {'name': name, 'description': null};

    try {
      await _apiClient.postJson(OfflineActions.createDepartment, payload);
      await _loadDepartments();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Department created.'),
          backgroundColor: AppTheme.successColor,
        ),
      );
    } catch (_) {
      await _syncQueue.enqueue(
        method: 'POST',
        path: OfflineActions.createDepartment,
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
      setState(() {
        _departments.add({'name': name, 'head': 'Unassigned', 'count': '0'});
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Departments'),
        actions: [
          IconButton(
            onPressed: _addDepartment,
            icon: const Icon(Icons.add_outlined),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _departments.length,
              itemBuilder: (context, index) {
                final dept = _departments[index];
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: ListTile(
                      title: Text(dept['name']?.toString() ?? ''),
                      subtitle: Text('Head: ${dept['head'] ?? 'Unassigned'}'),
                      trailing: SizedBox(
                        width: 132,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  dept['count']?.toString() ?? '0',
                                  style: AppTheme.heading3,
                                ),
                                const Text('Staff', style: AppTheme.caption),
                              ],
                            ),
                            const SizedBox(width: 10),
                            IconButton(
                              onPressed: () => _showAssignHeadDialog(dept),
                              icon: const Icon(Icons.manage_accounts_outlined),
                              tooltip: 'Assign head',
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addDepartment,
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _loadDepartments() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final responses = await Future.wait([
        _apiClient.get('/api/departments'),
        _apiClient.get('/api/users'),
      ]);
      final response = responses[0];
      final usersResponse = responses[1];

      if (usersResponse.statusCode == 200) {
        final usersList = List<Map<String, dynamic>>.from(
          jsonDecode(usersResponse.body) as List<dynamic>,
        );
        final users = usersList.map((item) {
          final data = item['data'] as Map<String, dynamic>? ?? {};
          return {
            'id': item['id']?.toString() ?? '',
            'name':
                data['fullName']?.toString() ??
                data['email']?.toString() ??
                item['id']?.toString() ??
                '-',
            'role': (data['role'] ?? 'employee').toString().toLowerCase(),
            'departmentId': data['departmentId']?.toString() ?? '',
          };
        }).toList();
        _users
          ..clear()
          ..addAll(users);
        _managers
          ..clear()
          ..addAll(users.where((user) => user['role'] == 'manager'));
      }

      if (response.statusCode == 200) {
        final list = List<Map<String, dynamic>>.from(
          jsonDecode(response.body) as List<dynamic>,
        );
        final mapped = list.map((item) {
          final data = item['data'] as Map<String, dynamic>? ?? {};
          final name = data['name']?.toString() ?? 'Department';
          final staffCount = _users
              .where((user) => user['departmentId']?.toString() == name)
              .length;
          return {
            'id': item['id']?.toString(),
            'name': name,
            'headUserId': data['headUserId']?.toString(),
            'head': data['headName'] ?? data['head'] ?? 'Unassigned',
            'count': staffCount.toString(),
          };
        }).toList();

        setState(() {
          _departments
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

  Future<void> _showAssignHeadDialog(Map<String, dynamic> department) async {
    if (_managers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No managers found. Make a staff member Manager first.')),
      );
      return;
    }

    String? selectedManagerId = department['headUserId']?.toString();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Assign Head - ${department['name'] ?? 'Department'}'),
        content: DropdownButtonFormField<String>(
          initialValue: _managers.any(
            (manager) => manager['id']?.toString() == selectedManagerId,
          )
              ? selectedManagerId
              : null,
          items: _managers
              .map(
                (manager) => DropdownMenuItem<String>(
                  value: manager['id']?.toString(),
                  child: Text(manager['name']?.toString() ?? '-'),
                ),
              )
              .toList(),
          onChanged: (value) {
            selectedManagerId = value;
          },
          decoration: const InputDecoration(labelText: 'Manager'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, selectedManagerId),
            child: const Text('Assign'),
          ),
        ],
      ),
    );

    if (result == null || result.isEmpty) {
      return;
    }
    await _assignDepartmentHead(department, result);
  }

  Future<void> _assignDepartmentHead(
    Map<String, dynamic> department,
    String managerId,
  ) async {
    final manager = _managers.firstWhere(
      (item) => item['id']?.toString() == managerId,
      orElse: () => {},
    );
    final departmentId = department['id']?.toString();
    if (departmentId == null || departmentId.isEmpty || manager.isEmpty) {
      return;
    }

    final response = await _apiClient.postJson('/api/departments/head', {
      'departmentId': departmentId,
      'headUserId': managerId,
      'headName': manager['name']?.toString(),
    });

    if (!mounted) {
      return;
    }
    if (response.statusCode == 200) {
      await _loadDepartments();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Department head assigned.')),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Assign failed: ${response.statusCode}')),
    );
  }
}
