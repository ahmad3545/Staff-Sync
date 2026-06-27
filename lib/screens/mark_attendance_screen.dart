import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:fyp/services/api_client.dart';
import 'package:fyp/utils/app_theme.dart';

class MarkAttendanceScreen extends StatefulWidget {
  const MarkAttendanceScreen({super.key});

  @override
  State<MarkAttendanceScreen> createState() => _MarkAttendanceScreenState();
}

class _MarkAttendanceScreenState extends State<MarkAttendanceScreen> {
  DateTime _selectedDate = DateTime.now();
  final List<Map<String, dynamic>> _staff = [];
  bool _isLoading = false;
  final ApiClient _apiClient = ApiClient();

  @override
  void initState() {
    super.initState();
    _loadStaff();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2023),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mark Attendance')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Date: ${_selectedDate.toLocal().toString().split(' ')[0]}',
                    style: AppTheme.heading3,
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _pickDate,
                  icon: const Icon(Icons.calendar_today_outlined),
                  label: const Text('Change'),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _staff.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'No staff found. Add staff first or ensure user profiles are saved.',
                      style: TextStyle(color: Colors.black54),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _staff.length,
                    itemBuilder: (context, index) {
                      final member = _staff[index];
                      return Card(
                        child: SwitchListTile(
                          title: Text(member['name'] as String),
                          subtitle: Text(member['role'] as String),
                          value: member['present'] as bool,
                          onChanged: (value) {
                            setState(() {
                              member['present'] = value;
                            });
                          },
                          activeThumbColor: AppTheme.successColor,
                        ),
                      );
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _saveAttendance,
                icon: const Icon(Icons.save_outlined),
                label: const Text('Save Attendance'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _loadStaff() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await _apiClient.get('/api/users');
      if (response.statusCode == 200) {
        final list = List<Map<String, dynamic>>.from(
          jsonDecode(response.body) as List<dynamic>,
        );
        final mapped = list.map((item) {
          final data = item['data'] as Map<String, dynamic>? ?? {};
          final role = (data['role'] ?? 'Employee').toString();
          return {
            'id': item['id'],
            'name': data['fullName'] ?? item['id'] ?? 'User',
            'role': _normalizeRole(role),
            'present': false,
          };
        }).toList();

        setState(() {
          _staff
            ..clear()
            ..addAll(mapped);
        });
      } else if (response.statusCode == 403) {
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Admin access required to load staff.'),
            backgroundColor: AppTheme.warningColor,
          ),
        );
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

  Future<void> _saveAttendance() async {
    final selected = _staff
        .where((member) => member['present'] == true)
        .toList();
    if (selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one staff member.')),
      );
      return;
    }

    final timestamp = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      9,
    ).toUtc();

    final records = selected
        .map(
          (member) => {
            'userId': member['id'],
            'timestampUtc': timestamp.toIso8601String(),
            'status': 'present',
          },
        )
        .toList();

    try {
      final response = await _apiClient.postJson('/api/attendance/mark-batch', {
        'records': records,
      });
      if (response.statusCode != 200) {
        throw Exception('Attendance update failed');
      }
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Attendance saved.')));
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to save attendance.'),
          backgroundColor: AppTheme.warningColor,
        ),
      );
    }
  }

  String _normalizeRole(String role) {
    final normalized = role.toLowerCase();
    if (normalized == 'admin') {
      return 'Admin';
    }
    if (normalized == 'manager') {
      return 'Manager';
    }
    return 'Employee';
  }
}
