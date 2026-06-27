import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:fyp/services/api_client.dart';
import 'package:fyp/services/user_context.dart';
import 'package:fyp/utils/app_theme.dart';
import 'package:intl/intl.dart';

class ViewAttendanceScreen extends StatefulWidget {
  const ViewAttendanceScreen({super.key});

  @override
  State<ViewAttendanceScreen> createState() => _ViewAttendanceScreenState();
}

class _ViewAttendanceScreenState extends State<ViewAttendanceScreen> {
  DateTime? _fromDate;
  DateTime? _toDate;
  bool _isLoading = false;
  final List<Map<String, dynamic>> _allRecords = [];
  final List<Map<String, dynamic>> _records = [];
  final ApiClient _apiClient = ApiClient();
  final UserContext _userContext = UserContext();
  final Map<String, String> _userNames = {};

  @override
  void initState() {
    super.initState();
    _loadRecords();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('View Attendance')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildFiltersCard(),
            const SizedBox(height: 16),
            _buildResultsHeader(),
            const SizedBox(height: 8),
            _buildResultsList(),
          ],
        ),
      ),
    );
  }

  Widget _buildFiltersCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Filter by Date Range',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildDateField(
                  label: 'From',
                  value: _fromDate,
                  onTap: () => _pickDate(isFrom: true),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildDateField(
                  label: 'To',
                  value: _toDate,
                  onTap: () => _pickDate(isFrom: false),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _onViewPressed,
              icon: const Icon(Icons.search),
              label: const Text('View Records'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateField({
    required String label,
    required DateTime? value,
    required VoidCallback onTap,
  }) {
    final text = value == null
        ? 'Select Date'
        : '${value.day.toString().padLeft(2, '0')} '
              '${_monthName(value.month)} ${value.year}';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(12),
          color: Colors.white,
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '$label: $text',
                style: TextStyle(
                  fontSize: 12,
                  color: value == null ? Colors.grey : Colors.black87,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Attendance Records',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '${_records.length} records',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.primaryColor,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildResultsList() {
    if (_records.isEmpty && !_isLoading) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text(
          'No attendance records found for the selected period.',
          style: TextStyle(fontSize: 13, color: Colors.black54),
        ),
      );
    }

    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return Column(children: _records.map(_buildRecordCard).toList());
  }

  Widget _buildRecordCard(Map<String, dynamic> record) {
    final status = record['status']?.toString() ?? 'Present';
    final statusColor = _statusColor(status);
    final timeLabel = record['timeLabel']?.toString() ?? _timeLabel(status);
    final dateValue = record['dateValue'] as DateTime?;
    final dateText = dateValue == null
        ? record['date']?.toString() ?? '-'
        : DateFormat('dd MMM yyyy').format(dateValue);
    final timeText = dateValue == null
        ? record['time']?.toString() ?? '--:--'
        : DateFormat('hh:mm a').format(dateValue);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
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
                record['name']?.toString() ?? '-',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
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
          const SizedBox(height: 8),
          _buildRow('Date', dateText),
          _buildRow(timeLabel, timeText),
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

  Future<void> _pickDate({required bool isFrom}) async {
    final initial = isFrom
        ? (_fromDate ?? DateTime.now())
        : (_toDate ?? DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2023),
      lastDate: DateTime(2030),
    );

    if (picked == null) {
      return;
    }

    setState(() {
      if (isFrom) {
        _fromDate = picked;
      } else {
        _toDate = picked;
      }
    });
  }

  void _onViewPressed() {
    setState(() {
      _records
        ..clear()
        ..addAll(_filterRecords(_allRecords));
    });
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'late':
        return AppTheme.warningColor;
      case 'absent':
        return AppTheme.errorColor;
      case 'check_out':
        return Colors.orange;
      default:
        return AppTheme.successColor;
    }
  }

  String _statusText(String status) {
    switch (status.toLowerCase()) {
      case 'check_in':
        return 'Check In';
      case 'check_out':
        return 'Check Out';
      case 'present':
        return 'Present';
      default:
        return status.isEmpty ? 'Present' : status;
    }
  }

  String _timeLabel(String status) {
    switch (status.toLowerCase()) {
      case 'check_in':
        return 'Check In';
      case 'check_out':
        return 'Check Out';
      default:
        return 'Time';
    }
  }

  String _monthName(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return months[month - 1];
  }

  Future<void> _loadRecords() async {
    final userId = _userContext.userId;
    if (userId == null || userId.isEmpty) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final responses = await Future.wait([
        _apiClient.get('/api/attendance/recent', query: {'limit': '200'}),
        _apiClient.get('/api/users'),
      ]);

      final attendanceResponse = responses[0];
      final usersResponse = responses[1];

      if (usersResponse.statusCode == 200) {
        final users = List<Map<String, dynamic>>.from(
          jsonDecode(usersResponse.body) as List<dynamic>,
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

      if (attendanceResponse.statusCode == 200) {
        final list = List<Map<String, dynamic>>.from(
          jsonDecode(attendanceResponse.body) as List<dynamic>,
        );
        final mapped = list.map((item) {
          final data = item['data'] as Map<String, dynamic>? ?? {};
          final timestamp = _parseDate(data['timestampUtc']);
          final targetUserId = data['userId']?.toString() ?? '-';
          final status = data['status']?.toString() ?? 'present';
          return {
            'name': _userNames[targetUserId] ?? targetUserId,
            'dateValue': timestamp,
            'status': _statusText(status),
            'timeLabel': _timeLabel(status),
          };
        }).toList();

        setState(() {
          _allRecords
            ..clear()
            ..addAll(mapped);
          _records
            ..clear()
            ..addAll(_filterRecords(mapped));
        });
        return;
      }

      final response = await _apiClient.get('/api/attendance/$userId');
      if (response.statusCode == 200) {
        final list = List<Map<String, dynamic>>.from(
          jsonDecode(response.body) as List<dynamic>,
        );
        final mapped = list.map((item) {
          final data = item['data'] as Map<String, dynamic>? ?? {};
          final timestamp = _parseDate(data['timestampUtc']);
          final status = data['status']?.toString() ?? 'present';
          return {
            'name': userId,
            'dateValue': timestamp,
            'status': _statusText(status),
            'timeLabel': _timeLabel(status),
          };
        }).toList();

        setState(() {
          _allRecords
            ..clear()
            ..addAll(mapped);
          _records
            ..clear()
            ..addAll(_filterRecords(mapped));
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

  List<Map<String, dynamic>> _filterRecords(
    List<Map<String, dynamic>> records,
  ) {
    if (_fromDate == null && _toDate == null) {
      return records;
    }

    return records.where((record) {
      final parsed = record['dateValue'] as DateTime?;
      if (parsed == null) {
        return false;
      }
      if (_fromDate != null && parsed.isBefore(_fromDate!)) {
        return false;
      }
      final toDate = _toDate == null
          ? null
          : DateTime(_toDate!.year, _toDate!.month, _toDate!.day, 23, 59, 59);
      if (toDate != null && parsed.isAfter(toDate)) {
        return false;
      }
      return true;
    }).toList();
  }

  DateTime? _parseDate(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is String) {
      return DateTime.tryParse(value)?.toLocal();
    }
    if (value is DateTime) {
      return value.toLocal();
    }
    if (value is Map) {
      final seconds =
          value['seconds'] ??
          value['Seconds'] ??
          value['_seconds'] ??
          value['_Seconds'];
      final nanos =
          value['nanoseconds'] ??
          value['Nanoseconds'] ??
          value['nanos'] ??
          value['Nanos'] ??
          value['_nanoseconds'] ??
          value['_Nanoseconds'] ??
          0;
      if (seconds is int) {
        final nanosValue = nanos is int ? nanos : 0;
        return DateTime.fromMillisecondsSinceEpoch(
          seconds * 1000 + (nanosValue / 1000000).round(),
          isUtc: true,
        ).toLocal();
      }
      if (seconds is num) {
        final nanosValue = nanos is num ? nanos.toInt() : 0;
        return DateTime.fromMillisecondsSinceEpoch(
          seconds.toInt() * 1000 + (nanosValue / 1000000).round(),
          isUtc: true,
        ).toLocal();
      }
    }
    if (value is int) {
      final isMilliseconds = value > 100000000000;
      return DateTime.fromMillisecondsSinceEpoch(
        isMilliseconds ? value : value * 1000,
        isUtc: true,
      ).toLocal();
    }
    return null;
  }
}
