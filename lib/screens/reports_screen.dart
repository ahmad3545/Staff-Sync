import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fyp/services/api_client.dart';
import 'package:fyp/services/offline_actions.dart';
import 'package:fyp/services/sync_queue_service.dart';
import 'package:fyp/services/user_context.dart';
import 'package:fyp/utils/app_theme.dart';
import 'package:fyp/utils/byte_downloader.dart';
import 'package:intl/intl.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  String _selectedType = 'Attendance';
  String _selectedRange = 'This Month';
  final ApiClient _apiClient = ApiClient();
  final SyncQueueService _syncQueue = SyncQueueService();
  final UserContext _userContext = UserContext();
  final List<Map<String, dynamic>> _reports = [];
  bool _isLoading = false;
  int _totalReports = 0;
  int _generatedReports = 0;

  final List<String> _types = const ['Attendance', 'Leave', 'Tasks', 'Payroll'];

  final List<String> _ranges = const [
    'This Week',
    'This Month',
    'Last Month',
    'Custom Range',
  ];

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reports')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildFiltersCard(),
            const SizedBox(height: 16),
            _buildSummaryCards(),
            const SizedBox(height: 16),
            _buildReportsList(),
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
            'Generate Report',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          _buildDropdown(
            label: 'Report Type',
            value: _selectedType,
            items: _types,
            onChanged: (value) {
              if (value == null) {
                return;
              }
              setState(() {
                _selectedType = value;
              });
            },
          ),
          const SizedBox(height: 12),
          _buildDropdown(
            label: 'Date Range',
            value: _selectedRange,
            items: _ranges,
            onChanged: (value) {
              if (value == null) {
                return;
              }
              setState(() {
                _selectedRange = value;
              });
            },
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _generateReport,
              icon: const Icon(Icons.bar_chart),
              label: const Text('Generate'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          initialValue: value,
          items: items
              .map((item) => DropdownMenuItem(value: item, child: Text(item)))
              .toList(),
          onChanged: onChanged,
          decoration: const InputDecoration(),
        ),
      ],
    );
  }

  Widget _buildSummaryCards() {
    return Row(
      children: [
        Expanded(
          child: _buildSummaryCard(
            'Total Reports',
            '$_totalReports',
            AppTheme.primaryColor,
            Icons.description,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildSummaryCard(
            'Generated',
            '$_generatedReports',
            AppTheme.successColor,
            Icons.check_circle,
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(
    String label,
    String value,
    Color color,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
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
          Icon(icon, color: color),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        ],
      ),
    );
  }

  Widget _buildReportsList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Recent Reports',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        if (_isLoading)
          const Center(child: CircularProgressIndicator())
        else
          ..._reports.map(_buildReportCard),
      ],
    );
  }

  Widget _buildReportCard(Map<String, dynamic> report) {
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
      child: Row(
        children: [
          const Icon(Icons.insert_drive_file, color: AppTheme.primaryColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  report['title'] ?? '-',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  report['period'] ?? '-',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          Text(
            report['status'] ?? '-',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.successColor,
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.download, size: 20),
            onPressed:
                report['status']?.toString().toLowerCase() == 'generated' ||
                    report['status']?.toString().toLowerCase() == 'completed'
                ? () => _downloadReport(report)
                : null,
            tooltip:
                report['status']?.toString().toLowerCase() == 'generated' ||
                    report['status']?.toString().toLowerCase() == 'completed'
                ? 'Download report'
                : 'Report not ready yet',
          ),
        ],
      ),
    );
  }

  void _generateReport() {
    final userId = _userContext.userId;
    if (userId == null || userId.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please login first.')));
      return;
    }

    final range = _resolveRange();
    final payload = {
      'userId': userId,
      'fromUtc': range.$1.toUtc().toIso8601String(),
      'toUtc': range.$2.toUtc().toIso8601String(),
      'type': _selectedType.toLowerCase(),
    };

    _submitReport(payload, range);
  }

  Future<void> _submitReport(
    Map<String, dynamic> payload,
    (DateTime, DateTime) range,
  ) async {
    try {
      final response = await _apiClient.postJson(
        OfflineActions.generateReport,
        payload,
      );
      if (response.statusCode != 200) {
        throw Exception('Report generation failed');
      }
      if (!mounted) {
        return;
      }
      await _loadReports();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Generated $_selectedType report.'),
          backgroundColor: AppTheme.successColor,
        ),
      );
    } catch (_) {
      await _syncQueue.enqueue(
        method: 'POST',
        path: OfflineActions.generateReport,
        body: payload,
      );
      if (!mounted) {
        return;
      }
      await _loadReports();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Saved offline. Will sync when online.'),
          backgroundColor: AppTheme.warningColor,
        ),
      );
    }
  }

  Future<void> _downloadReport(Map<String, dynamic> report) async {
    final type = report['type']?.toString().toLowerCase();
    final userId = report['userId']?.toString() ?? _userContext.userId;
    final from = _parseDate(report['fromUtc'])?.toUtc();
    final to = _parseDate(report['toUtc'])?.toUtc();

    if (type == null || userId == null || from == null || to == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to determine report parameters for download.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final pathSegment = type == 'leave' ? 'leaves' : type;
    final query = {
      'userId': userId,
      'fromUtc': from.toIso8601String(),
      'toUtc': to.toIso8601String(),
      'format': 'csv',
    };

    try {
      final response = await _apiClient.get(
        '/api/exports/$pathSegment',
        query: query,
      );
      if (response.statusCode != 200) {
        throw Exception(
          'Export request failed with status ${response.statusCode}',
        );
      }

      final bytes = response.bodyBytes;
      final fileName =
          '${type}_report_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.csv';
      final savedPath = await downloadBytes(fileName, bytes);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            kIsWeb
                ? 'Download started: $fileName'
                : 'Report saved to $savedPath',
          ),
          backgroundColor: AppTheme.successColor,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to download report: ${error.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _loadReports() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await _apiClient.get('/api/reports');
      if (response.statusCode == 200) {
        final list = List<Map<String, dynamic>>.from(
          jsonDecode(response.body) as List<dynamic>,
        );
        final formatter = DateFormat('MMM dd, yyyy');

        final mapped = list.map((item) {
          final data = item['data'] as Map<String, dynamic>? ?? {};
          final from = _parseDate(data['fromUtc']);
          final to = _parseDate(data['toUtc']);
          final type = data['type']?.toString() ?? 'report';
          final status = data['status']?.toString() ?? 'queued';

          return {
            'id': item['id']?.toString() ?? '',
            'title': '${_capitalize(type)} Report',
            'period': from == null || to == null
                ? '-'
                : '${formatter.format(from)} - ${formatter.format(to)}',
            'status': _capitalize(status),
            'type': type,
            'userId': data['userId']?.toString(),
            'fromUtc': data['fromUtc'],
            'toUtc': data['toUtc'],
          };
        }).toList();

        final generated = list.where((item) {
          final data = item['data'] as Map<String, dynamic>? ?? {};
          final status = data['status']?.toString().toLowerCase();
          return status == 'generated' || status == 'completed';
        }).length;

        setState(() {
          _reports
            ..clear()
            ..addAll(mapped);
          _totalReports = list.length;
          _generatedReports = generated;
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
    if (value == null) return null;

    // ISO string
    if (value is String) {
      return DateTime.tryParse(value)?.toLocal();
    }

    // JSON-encoded numeric timestamp (seconds or milliseconds)
    if (value is int) {
      // Heuristic: treat large ints (>1e12) as milliseconds
      if (value > 1000000000000) {
        return DateTime.fromMillisecondsSinceEpoch(value).toLocal();
      }
      // otherwise treat as seconds
      return DateTime.fromMillisecondsSinceEpoch(value * 1000).toLocal();
    }
    if (value is double) {
      final v = value.toInt();
      if (v > 1000000000000) {
        return DateTime.fromMillisecondsSinceEpoch(v).toLocal();
      }
      return DateTime.fromMillisecondsSinceEpoch(v * 1000).toLocal();
    }

    // Firestore-like map shape: {"seconds":..., "nanoseconds":...} or _seconds
    if (value is Map) {
      final seconds = value['seconds'] ?? value['_seconds'];
      final nanos = value['nanoseconds'] ?? value['_nanoseconds'] ?? 0;
      if (seconds is int || seconds is double) {
        final ms =
            (seconds is int ? seconds : (seconds as double).toInt()) * 1000 +
            (nanos is int ? (nanos / 1000000).toInt() : 0);
        return DateTime.fromMillisecondsSinceEpoch(ms).toLocal();
      }
      // Sometimes Firestore returns nested objects; try parsing string inside
      final asString = value.toString();
      return DateTime.tryParse(asString)?.toLocal();
    }

    return null;
  }

  String _capitalize(String value) {
    if (value.isEmpty) {
      return value;
    }
    return '${value[0].toUpperCase()}${value.substring(1)}';
  }

  (DateTime, DateTime) _resolveRange() {
    final now = DateTime.now();
    switch (_selectedRange) {
      case 'This Week':
        final start = now.subtract(Duration(days: now.weekday - 1));
        final end = start.add(const Duration(days: 6));
        return (start, end);
      case 'Last Month':
        final firstOfThisMonth = DateTime(now.year, now.month, 1);
        final lastMonthEnd = firstOfThisMonth.subtract(const Duration(days: 1));
        final lastMonthStart = DateTime(
          lastMonthEnd.year,
          lastMonthEnd.month,
          1,
        );
        return (lastMonthStart, lastMonthEnd);
      case 'Custom Range':
        final start = now.subtract(const Duration(days: 30));
        return (start, now);
      case 'This Month':
      default:
        final start = DateTime(now.year, now.month, 1);
        final end = DateTime(now.year, now.month + 1, 0);
        return (start, end);
    }
  }
}
