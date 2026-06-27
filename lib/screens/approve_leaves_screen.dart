import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:fyp/services/api_client.dart';
import 'package:fyp/services/offline_actions.dart';
import 'package:fyp/services/sync_queue_service.dart';
import 'package:fyp/services/user_context.dart';
import 'package:fyp/utils/app_theme.dart';
import 'package:intl/intl.dart';

class ApproveLeavesScreen extends StatefulWidget {
  const ApproveLeavesScreen({super.key});

  @override
  State<ApproveLeavesScreen> createState() => _ApproveLeavesScreenState();
}

class _ApproveLeavesScreenState extends State<ApproveLeavesScreen> {
  final List<Map<String, dynamic>> _requests = [];
  bool _isLoading = false;
  final ApiClient _apiClient = ApiClient();
  final SyncQueueService _syncQueue = SyncQueueService();
  final UserContext _userContext = UserContext();
  final Map<String, String> _userNames = {};
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Approved':
        return AppTheme.successColor;
      case 'Rejected':
        return AppTheme.errorColor;
      default:
        return AppTheme.warningColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Approve Leaves')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _requests.length + (_errorMessage == null ? 0 : 1),
              itemBuilder: (context, index) {
                if (_errorMessage != null && index == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: AppTheme.warningColor),
                    ),
                  );
                }

                final requestIndex = _errorMessage == null ? index : index - 1;
                if (requestIndex < 0 || requestIndex >= _requests.length) {
                  return const SizedBox.shrink();
                }

                final request = _requests[requestIndex];
                final status = request['status']?.toString() ?? 'Pending';
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                request['name']?.toString() ?? '-',
                                style: AppTheme.heading3,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: _statusColor(status).withOpacity(0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                status,
                                style: TextStyle(
                                  color: _statusColor(status),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text('${request['type']} • ${request['dates']}'),
                        const SizedBox(height: 6),
                        Text(
                          request['reason']?.toString() ?? '-',
                          style: AppTheme.bodySmall,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: status == 'Pending'
                                    ? () => _updateStatus(
                                        request['id']?.toString() ?? '',
                                        'rejected',
                                      )
                                    : null,
                                child: const Text('Reject'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: status == 'Pending'
                                    ? () => _updateStatus(
                                        request['id']?.toString() ?? '',
                                        'approved',
                                      )
                                    : null,
                                child: const Text('Approve'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  Future<void> _loadRequests() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final results = await Future.wait([
        _apiClient.get('/api/leave'),
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
        final list = List<Map<String, dynamic>>.from(
          jsonDecode(results[0].body) as List<dynamic>,
        );
        final mapped = list.map((item) {
          final data = item['data'] as Map<String, dynamic>? ?? {};
          final start = _parseDate(data['startDateUtc']);
          final end = _parseDate(data['endDateUtc']);
          final userId = data['userId']?.toString() ?? '-';
          return {
            'id': item['id'],
            'name': _userNames[userId] ?? userId,
            'type': 'Leave',
            'dates': '${_formatDate(start)} - ${_formatDate(end)}',
            'reason': data['reason'] ?? '-',
            'status': (data['status'] ?? 'pending').toString().capitalize(),
          };
        }).toList();

        setState(() {
          _requests
            ..clear()
            ..addAll(mapped);
        });
        _errorMessage = null;
      } else if (results[0].statusCode == 401 || results[0].statusCode == 403) {
        _errorMessage = 'Admin access required. Logout/login as admin.';
      } else {
        _errorMessage =
            'Failed to load leave requests (status ${results[0].statusCode}).';
      }
    } catch (_) {
      _errorMessage = 'Unable to reach server. Check backend/CORS.';
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _updateStatus(String leaveId, String status) async {
    if (leaveId.isEmpty) {
      return;
    }
    final payload = {
      'leaveId': leaveId,
      'status': status,
      'approverId': _userContext.userId,
      'notes': null,
    };

    try {
      await _apiClient.postJson(OfflineActions.approveLeave, payload);
      await _loadRequests();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Leave updated.')));
    } catch (_) {
      await _syncQueue.enqueue(
        method: 'POST',
        path: OfflineActions.approveLeave,
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

  DateTime? _parseDate(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is String) {
      return DateTime.tryParse(value)?.toLocal();
    }
    return null;
  }

  String _formatDate(DateTime? date) {
    if (date == null) {
      return '-';
    }
    return DateFormat('MMM dd, yyyy').format(date);
  }
}

extension _Capitalize on String {
  String capitalize() {
    if (isEmpty) {
      return this;
    }
    return '${this[0].toUpperCase()}${substring(1)}';
  }
}
