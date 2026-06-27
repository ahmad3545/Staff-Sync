import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:fyp/services/api_client.dart';
import 'package:fyp/services/user_context.dart';
import 'package:fyp/utils/app_theme.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  CalendarFormat _calendarFormat = CalendarFormat.month;
  bool _isLoading = false;
  final List<Map<String, dynamic>> _shifts = [];
  final ApiClient _apiClient = ApiClient();
  final UserContext _userContext = UserContext();

  @override
  void initState() {
    super.initState();
    _loadShifts();
  }

  @override
  Widget build(BuildContext context) {
    final shifts = _filterShifts();

    return Scaffold(
      appBar: AppBar(title: const Text('Schedule')),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Calendar
            Card(
              margin: const EdgeInsets.all(16),
              child: TableCalendar(
                firstDay: DateTime.utc(2024, 1, 1),
                lastDay: DateTime.utc(2026, 12, 31),
                focusedDay: _focusedDay,
                selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                calendarFormat: _calendarFormat,
                onDaySelected: (selectedDay, focusedDay) {
                  setState(() {
                    _selectedDay = selectedDay;
                    _focusedDay = focusedDay;
                  });
                },
                onFormatChanged: (format) {
                  setState(() {
                    _calendarFormat = format;
                  });
                },
                calendarStyle: const CalendarStyle(
                  todayDecoration: BoxDecoration(
                    color: AppTheme.secondaryColor,
                    shape: BoxShape.circle,
                  ),
                  selectedDecoration: BoxDecoration(
                    color: AppTheme.primaryColor,
                    shape: BoxShape.circle,
                  ),
                  markersMaxCount: 1,
                ),
                headerStyle: const HeaderStyle(
                  formatButtonVisible: true,
                  titleCentered: true,
                ),
              ),
            ),

            // Filter Tabs
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: const Center(child: Text('Day')),
                      selected: true,
                      onSelected: (selected) {},
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ChoiceChip(
                      label: const Center(child: Text('Week')),
                      selected: false,
                      onSelected: (selected) {},
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ChoiceChip(
                      label: const Center(child: Text('Month')),
                      selected: false,
                      onSelected: (selected) {},
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Shifts List
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Upcoming Shifts', style: AppTheme.heading3),
                  const SizedBox(height: 12),
                  if (_isLoading)
                    const Center(child: CircularProgressIndicator())
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: shifts.length,
                      itemBuilder: (context, index) {
                        final shift = shifts[index];
                        final shiftColor = _shiftColor(shift['type']);

                        return Card(
                          child: ListTile(
                            leading: Container(
                              width: 8,
                              height: 60,
                              decoration: BoxDecoration(
                                color: shiftColor,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            title: Text(
                              shift['title']?.toString() ?? '-',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Text(
                                  '${shift['date']} • ${shift['startTime']} - ${shift['endTime']}',
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.location_on,
                                      size: 14,
                                      color: Colors.grey,
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        shift['location']?.toString() ?? '-',
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Role: ${shift['role'] ?? '-'}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            trailing: IconButton(
                              icon: const Icon(
                                Icons.arrow_forward_ios,
                                size: 16,
                              ),
                              onPressed: () {
                                _showShiftDetails(shift);
                              },
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showShiftDetails(Map<String, dynamic> shift) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(shift['title']),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Date: ${shift['date']}'),
            Text('Time: ${shift['startTime']} - ${shift['endTime']}'),
            Text('Location: ${shift['location']}'),
            Text('Role: ${shift['role']}'),
            Text('Department: ${shift['department']}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
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
            'date': start == null
                ? '-'
                : DateFormat('MMM dd, yyyy').format(start),
            'startTime': start == null
                ? '-'
                : DateFormat('hh:mm a').format(start),
            'endTime': end == null ? '-' : DateFormat('hh:mm a').format(end),
            'location': data['location'] ?? '-',
            'role': data['role'] ?? '-',
            'department': data['department'] ?? '-',
            'type': _shiftType(start),
            'start': start,
            'assignedUserIds': assigned
                .map((value) => value.toString())
                .toList(),
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

  List<Map<String, dynamic>> _filterShifts() {
    final userId = _userContext.userId;
    final assignedOnly = userId == null || userId.isEmpty
        ? _shifts
        : _shifts.where((shift) {
            final assignedIds =
                (shift['assignedUserIds'] as List<dynamic>? ?? [])
                    .map((value) => value.toString())
                    .toList();
            return assignedIds.contains(userId);
          }).toList();

    if (_selectedDay == null) {
      return assignedOnly;
    }
    return assignedOnly.where((shift) {
      final start = shift['start'] as DateTime?;
      if (start == null) {
        return true;
      }
      return isSameDay(start, _selectedDay);
    }).toList();
  }

  Color _shiftColor(String? type) {
    switch (type) {
      case 'morning':
        return AppTheme.morningShift;
      case 'evening':
        return AppTheme.eveningShift;
      case 'night':
        return AppTheme.nightShift;
      default:
        return AppTheme.primaryColor;
    }
  }

  String _shiftType(DateTime? start) {
    if (start == null) {
      return 'day';
    }
    if (start.hour < 12) {
      return 'morning';
    }
    if (start.hour < 18) {
      return 'evening';
    }
    return 'night';
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
}
