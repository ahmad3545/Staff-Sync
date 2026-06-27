import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:fyp/services/api_client.dart';
import 'package:fyp/utils/app_theme.dart';
import 'package:intl/intl.dart';

class ShiftManagementScreen extends StatefulWidget {
  const ShiftManagementScreen({super.key});

  @override
  State<ShiftManagementScreen> createState() => _ShiftManagementScreenState();
}

class _ShiftManagementScreenState extends State<ShiftManagementScreen> {
  String _selectedDay = 'Today';
  final List<String> _days = const ['Today', 'Tomorrow', 'This Week'];
  final List<Map<String, dynamic>> _shifts = [];
  final List<Map<String, dynamic>> _users = [];
  bool _isLoading = false;
  final ApiClient _apiClient = ApiClient();

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  Widget build(BuildContext context) {
    final totalShifts = _shifts.length;
    final activeShifts = _shifts
        .where((shift) => shift['status'] == 'active')
        .length;
    final scheduledShifts = _shifts
        .where((shift) => shift['status'] == 'scheduled')
        .length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Shift Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              _showShiftDialog();
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildFilterCard(),
            const SizedBox(height: 16),
            _buildOverviewCards(
              totalShifts: totalShifts,
              activeShifts: activeShifts,
              scheduledShifts: scheduledShifts,
            ),
            const SizedBox(height: 12),
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else
              ..._shifts.map(_buildShiftCard),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterCard() {
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
          const Text(
            'Filter Shifts',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _selectedDay,
            items: _days
                .map((day) => DropdownMenuItem(value: day, child: Text(day)))
                .toList(),
            onChanged: (value) {
              if (value == null) {
                return;
              }
              setState(() {
                _selectedDay = value;
              });
            },
            decoration: const InputDecoration(labelText: 'Day'),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewCards({
    required int totalShifts,
    required int activeShifts,
    required int scheduledShifts,
  }) {
    return Row(
      children: [
        Expanded(
          child: _buildOverviewCard(
            'Total Shifts',
            '$totalShifts',
            AppTheme.primaryColor,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildOverviewCard(
            'Active',
            '$activeShifts',
            AppTheme.successColor,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildOverviewCard(
            'Scheduled',
            '$scheduledShifts',
            AppTheme.warningColor,
          ),
        ),
      ],
    );
  }

  Widget _buildOverviewCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
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
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Colors.black54),
          ),
        ],
      ),
    );
  }

  Widget _buildShiftCard(Map<String, dynamic> shift) {
    final status = shift['status']?.toString() ?? 'active';
    final statusColor = status.toLowerCase() == 'active'
        ? AppTheme.successColor
        : AppTheme.warningColor;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                shift['title']?.toString() ?? '-',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          _buildRow('Time', shift['time']?.toString() ?? '-'),
          _buildRow('Location', shift['location']?.toString() ?? '-'),
          _buildRow('Assigned', shift['assigned']?.toString() ?? '-'),
          const SizedBox(height: 8),
          Row(
            children: [
              OutlinedButton(
                onPressed: () {
                  _showShiftDialog(shift: shift);
                },
                child: const Text('Edit'),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: () {
                  _showAssignDialog(shift);
                },
                child: const Text('Assign Staff'),
              ),
              const SizedBox(width: 12),
              OutlinedButton(
                onPressed: () {
                  _confirmDeleteShift(shift);
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.errorColor,
                ),
                child: const Text('Delete'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _loadInitialData() async {
    await Future.wait([_loadUsers(), _loadShifts()]);
  }

  Future<void> _loadUsers() async {
    try {
      final response = await _apiClient.get('/api/users');
      if (response.statusCode == 200) {
        final list = List<Map<String, dynamic>>.from(
          jsonDecode(response.body) as List<dynamic>,
        );
        final mapped = list.map((item) {
          final data = item['data'] as Map<String, dynamic>? ?? {};
          return {
            'id': item['id'],
            'name':
                data['fullName']?.toString() ?? item['id']?.toString() ?? '-',
            'email': data['email']?.toString() ?? '-',
            'role': data['role']?.toString() ?? 'employee',
          };
        }).toList();

        if (mounted) {
          setState(() {
            _users
              ..clear()
              ..addAll(mapped);
          });
        }
      }
    } catch (_) {
      // Ignore load errors.
    }
  }

  Future<void> _loadShifts() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await _apiClient.get('/api/shifts');
      if (response.statusCode == 200) {
        final list = List<Map<String, dynamic>>.from(
          jsonDecode(response.body) as List<dynamic>,
        );
        final mapped = list.map((item) {
          final data = item['data'] as Map<String, dynamic>? ?? {};
          final start = _parseDate(data['startTimeUtc']);
          final end = _parseDate(data['endTimeUtc']);
          final assigned = (data['assignedUserIds'] as List<dynamic>?) ?? [];
          return {
            'id': item['id'],
            'title': data['name'] ?? 'Shift',
            'name': data['name'] ?? 'Shift',
            'time': '${_formatTime(start)} - ${_formatTime(end)}',
            'location': data['location'] ?? '-',
            'assigned': '${assigned.length} staff',
            'assignedUserIds': assigned.map((e) => e.toString()).toList(),
            'status': data['status'] ?? 'scheduled',
            'startTimeUtc': start,
            'endTimeUtc': end,
          };
        }).toList();

        setState(() {
          _shifts
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

  Future<void> _showShiftDialog({Map<String, dynamic>? shift}) async {
    final nameController = TextEditingController(
      text: shift?['name']?.toString() ?? '',
    );
    final locationController = TextEditingController(
      text: shift?['location']?.toString() ?? '',
    );
    final statusOptions = ['scheduled', 'active', 'inactive'];
    String selectedStatus = shift?['status']?.toString() ?? 'scheduled';
    DateTime? startDate = shift?['startTimeUtc'] as DateTime?;
    DateTime? endDate = shift?['endTimeUtc'] as DateTime?;
    bool isSaving = false;

    Future<void> pickDate({
      required bool isStart,
      required StateSetter setDialogState,
    }) async {
      final initial = isStart
          ? (startDate ?? DateTime.now())
          : (endDate ?? DateTime.now());
      final picked = await showDatePicker(
        context: context,
        initialDate: initial,
        firstDate: DateTime(2020),
        lastDate: DateTime(2100),
      );
      if (picked == null) {
        return;
      }
      final time = TimeOfDay.fromDateTime(
        isStart ? (startDate ?? DateTime.now()) : (endDate ?? DateTime.now()),
      );
      if (isStart) {
        startDate = DateTime(
          picked.year,
          picked.month,
          picked.day,
          time.hour,
          time.minute,
        );
      } else {
        endDate = DateTime(
          picked.year,
          picked.month,
          picked.day,
          time.hour,
          time.minute,
        );
      }
      setDialogState(() {});
    }

    Future<void> pickTime({
      required bool isStart,
      required StateSetter setDialogState,
    }) async {
      final initial = TimeOfDay.fromDateTime(
        isStart ? (startDate ?? DateTime.now()) : (endDate ?? DateTime.now()),
      );
      final picked = await showTimePicker(
        context: context,
        initialTime: initial,
      );
      if (picked == null) {
        return;
      }
      final baseDate = isStart
          ? (startDate ?? DateTime.now())
          : (endDate ?? DateTime.now());
      final updated = DateTime(
        baseDate.year,
        baseDate.month,
        baseDate.day,
        picked.hour,
        picked.minute,
      );
      if (isStart) {
        startDate = updated;
      } else {
        endDate = updated;
      }
      setDialogState(() {});
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(shift == null ? 'Create Shift' : 'Edit Shift'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Shift Name',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: locationController,
                      decoration: const InputDecoration(labelText: 'Location'),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: selectedStatus,
                      decoration: const InputDecoration(labelText: 'Status'),
                      items: statusOptions
                          .map(
                            (value) => DropdownMenuItem(
                              value: value,
                              child: Text(value),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setDialogState(() {
                          selectedStatus = value;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => pickDate(
                              isStart: true,
                              setDialogState: setDialogState,
                            ),
                            child: Text(
                              startDate == null
                                  ? 'Pick Start Date'
                                  : DateFormat(
                                      'dd MMM yyyy, hh:mm a',
                                    ).format(startDate!),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => pickTime(
                              isStart: true,
                              setDialogState: setDialogState,
                            ),
                            child: const Text('Start Time'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => pickDate(
                              isStart: false,
                              setDialogState: setDialogState,
                            ),
                            child: Text(
                              endDate == null
                                  ? 'Pick End Date'
                                  : DateFormat(
                                      'dd MMM yyyy, hh:mm a',
                                    ).format(endDate!),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => pickTime(
                              isStart: false,
                              setDialogState: setDialogState,
                            ),
                            child: const Text('End Time'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving
                      ? null
                      : () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          final name = nameController.text.trim();
                          final location = locationController.text.trim();
                          if (name.isEmpty ||
                              startDate == null ||
                              endDate == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Name, start date, and end date are required',
                                ),
                              ),
                            );
                            return;
                          }
                          if (!endDate!.isAfter(startDate!)) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'End time must be after start time',
                                ),
                              ),
                            );
                            return;
                          }

                          setDialogState(() {
                            isSaving = true;
                          });

                          try {
                            final response = shift == null
                                ? await _apiClient.postJson('/api/shifts', {
                                    'name': name,
                                    'startTimeUtc': startDate!
                                        .toUtc()
                                        .toIso8601String(),
                                    'endTimeUtc': endDate!
                                        .toUtc()
                                        .toIso8601String(),
                                    'location': location,
                                    'status': selectedStatus,
                                  })
                                : await _apiClient.putJson('/api/shifts', {
                                    'shiftId': shift['id'],
                                    'name': name,
                                    'startTimeUtc': startDate!
                                        .toUtc()
                                        .toIso8601String(),
                                    'endTimeUtc': endDate!
                                        .toUtc()
                                        .toIso8601String(),
                                    'location': location,
                                    'status': selectedStatus,
                                  });

                            if (!mounted) return;
                            if (response.statusCode == 200) {
                              Navigator.pop(dialogContext);
                              await _loadShifts();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    shift == null
                                        ? 'Shift created'
                                        : 'Shift updated',
                                  ),
                                ),
                              );
                            } else {
                              setDialogState(() {
                                isSaving = false;
                              });
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Save failed: ${response.statusCode}',
                                  ),
                                ),
                              );
                            }
                          } catch (e) {
                            if (!mounted) return;
                            setDialogState(() {
                              isSaving = false;
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error saving shift: $e')),
                            );
                          }
                        },
                  child: Text(isSaving ? 'Saving' : 'Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showAssignDialog(Map<String, dynamic> shift) async {
    final assignedIds = Set<String>.from(
      (shift['assignedUserIds'] as List<dynamic>? ?? []).map(
        (value) => value.toString(),
      ),
    );
    bool isSaving = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Assign Staff to ${shift['title'] ?? 'Shift'}'),
              content: SizedBox(
                width: double.maxFinite,
                height: 320,
                child: _users.isEmpty
                    ? const Center(child: Text('No users found'))
                    : ListView.builder(
                        itemCount: _users.length,
                        itemBuilder: (context, index) {
                          final user = _users[index];
                          final userId = user['id']?.toString() ?? '';
                          final userName = user['name']?.toString() ?? userId;
                          final role = user['role']?.toString() ?? 'employee';
                          return CheckboxListTile(
                            value: assignedIds.contains(userId),
                            onChanged: (checked) {
                              setDialogState(() {
                                if (checked == true) {
                                  assignedIds.add(userId);
                                } else {
                                  assignedIds.remove(userId);
                                }
                              });
                            },
                            title: Text(userName),
                            subtitle: Text('$userId • $role'),
                          );
                        },
                      ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving
                      ? null
                      : () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          setDialogState(() {
                            isSaving = true;
                          });
                          try {
                            final response = await _apiClient
                                .postJson('/api/shifts/assign', {
                                  'shiftId': shift['id'],
                                  'userIds': assignedIds.toList(),
                                });

                            if (!mounted) return;
                            if (response.statusCode == 200) {
                              Navigator.pop(dialogContext);
                              await _loadShifts();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Shift assigned')),
                              );
                            } else {
                              setDialogState(() {
                                isSaving = false;
                              });
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Assign failed: ${response.statusCode}',
                                  ),
                                ),
                              );
                            }
                          } catch (e) {
                            if (!mounted) return;
                            setDialogState(() {
                              isSaving = false;
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error assigning shift: $e'),
                              ),
                            );
                          }
                        },
                  child: Text(isSaving ? 'Assigning' : 'Assign'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _confirmDeleteShift(Map<String, dynamic> shift) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Shift'),
          content: Text('Delete ${shift['title'] ?? 'this shift'}?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    try {
      final response = await _apiClient.delete('/api/shifts/${shift['id']}');
      if (response.statusCode == 200) {
        await _loadShifts();
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Shift deleted')));
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Delete failed: ${response.statusCode}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error deleting shift: $e')));
      }
    }
  }

  DateTime? _parseDate(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is String) {
      return DateTime.tryParse(value)?.toLocal();
    }
    return null;
  }

  String _formatTime(DateTime? value) {
    if (value == null) {
      return '-';
    }
    return DateFormat('hh:mm a').format(value);
  }
}
