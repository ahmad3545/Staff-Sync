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
                  child: ListTile(
                    title: Text(dept['name']?.toString() ?? ''),
                    subtitle: Text('Head: ${dept['head'] ?? 'Unassigned'}'),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          dept['count']?.toString() ?? '0',
                          style: AppTheme.heading3,
                        ),
                        const Text('Staff', style: AppTheme.caption),
                      ],
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
      final response = await _apiClient.get('/api/departments');
      if (response.statusCode == 200) {
        final list = List<Map<String, dynamic>>.from(
          jsonDecode(response.body) as List<dynamic>,
        );
        final mapped = list.map((item) {
          final data = item['data'] as Map<String, dynamic>? ?? {};
          return {
            'name': data['name'] ?? 'Department',
            'head': data['head'] ?? 'Unassigned',
            'count': data['count'] ?? '0',
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
}
