import 'package:flutter/material.dart';
import 'package:fyp/constants/app_constants.dart';
import 'dart:convert';

import 'package:fyp/services/api_client.dart';
import 'package:fyp/services/offline_actions.dart';
import 'package:fyp/services/sync_queue_service.dart';
import 'package:fyp/services/user_context.dart';
import 'package:fyp/utils/app_theme.dart';
import 'package:intl/intl.dart';

class LeaveRequestScreen extends StatefulWidget {
  const LeaveRequestScreen({super.key});

  @override
  State<LeaveRequestScreen> createState() => _LeaveRequestScreenState();
}

class _LeaveRequestScreenState extends State<LeaveRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();
  final List<String> _attachments = [];

  final ApiClient _apiClient = ApiClient();
  final UserContext _userContext = UserContext();
  final SyncQueueService _syncQueue = SyncQueueService();
  bool _isLoadingRequests = false;
  final List<Map<String, dynamic>> _leaveRequests = [];

  String _selectedLeaveType = 'Casual Leave';
  DateTime? _fromDate;
  DateTime? _toDate;
  int _totalDays = 0;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadLeaveRequests();
  }

  void _calculateDays() {
    if (_fromDate != null && _toDate != null) {
      setState(() {
        _totalDays = _toDate!.difference(_fromDate!).inDays + 1;
      });
    }
  }

  Future<void> _selectDate(BuildContext context, bool isFromDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
    );

    if (picked != null) {
      setState(() {
        if (isFromDate) {
          _fromDate = picked;
          if (_toDate != null && _toDate!.isBefore(_fromDate!)) {
            _toDate = null;
          }
        } else {
          _toDate = picked;
        }
        _calculateDays();
      });
    }
  }

  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_fromDate == null || _toDate == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select both dates')));
      return;
    }

    final userId = _userContext.userId;
    if (userId == null || userId.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please login first.')));
      return;
    }

    final payload = {
      'userId': userId,
      'startDateUtc': _fromDate!.toUtc().toIso8601String(),
      'endDateUtc': _toDate!.toUtc().toIso8601String(),
      'reason': _reasonController.text.trim(),
      'leaveType': _selectedLeaveType,
    };

    try {
      final response = await _apiClient.postJson(
        OfflineActions.requestLeave,
        payload,
      );
      if (response.statusCode != 200) {
        throw Exception('Leave request failed');
      }
      await _loadLeaveRequests();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Leave request submitted successfully!'),
          backgroundColor: AppTheme.successColor,
        ),
      );
    } catch (_) {
      await _syncQueue.enqueue(
        method: 'POST',
        path: OfflineActions.requestLeave,
        body: payload,
      );
      _leaveRequests.insert(0, {
        'reason': payload['reason'],
        'leaveType': payload['leaveType'],
        'fromDate': _fromDate == null
            ? '-'
            : DateFormat('MMM dd, yyyy').format(_fromDate!),
        'toDate': _toDate == null
            ? '-'
            : DateFormat('MMM dd, yyyy').format(_toDate!),
        'days': _totalDays,
        'status': 'queued',
      });
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

    // Clear form
    _reasonController.clear();
    setState(() {
      _fromDate = null;
      _toDate = null;
      _totalDays = 0;
      _attachments.clear();
    });
  }

  void _addAttachment(String source) {
    setState(() {
      _attachments.add('${source}_${_attachments.length + 1}.pdf');
    });
  }

  void _showAttachmentPicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Attach Document', style: AppTheme.heading3),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Scan with Camera'),
                onTap: () {
                  Navigator.pop(context);
                  _addAttachment('CameraScan');
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Choose from Gallery'),
                onTap: () {
                  Navigator.pop(context);
                  _addAttachment('Gallery');
                },
              ),
              ListTile(
                leading: const Icon(Icons.attach_file),
                title: const Text('Browse Files'),
                onTap: () {
                  Navigator.pop(context);
                  _addAttachment('Document');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final leaveRequests = _leaveRequests;
    const casualBalance = 0;
    const sickBalance = 0;
    const annualBalance = 0;

    return Scaffold(
      appBar: AppBar(title: const Text('Leave Request')),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Leave Balance Card
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppTheme.primaryColor, AppTheme.secondaryColor],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Available Leaves',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildLeaveBalance('Casual', casualBalance),
                      _buildLeaveBalance('Sick', sickBalance),
                      _buildLeaveBalance('Annual', annualBalance),
                    ],
                  ),
                ],
              ),
            ),

            // Leave Request Form
            Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('New Leave Request', style: AppTheme.heading3),
                    const SizedBox(height: 16),

                    // Leave Type Dropdown
                    DropdownButtonFormField<String>(
                      initialValue: _selectedLeaveType,
                      decoration: const InputDecoration(
                        labelText: 'Leave Type',
                        prefixIcon: Icon(Icons.category),
                      ),
                      items: AppConstants.leaveTypes.map((String type) {
                        return DropdownMenuItem(value: type, child: Text(type));
                      }).toList(),
                      onChanged: (String? newValue) {
                        setState(() {
                          _selectedLeaveType = newValue!;
                        });
                      },
                    ),
                    const SizedBox(height: 16),

                    // From Date
                    InkWell(
                      onTap: () => _selectDate(context, true),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'From Date',
                          prefixIcon: Icon(Icons.calendar_today),
                          suffixIcon: Icon(Icons.arrow_drop_down),
                        ),
                        child: Text(
                          _fromDate == null
                              ? 'Select date'
                              : DateFormat('MMM dd, yyyy').format(_fromDate!),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // To Date
                    InkWell(
                      onTap: () => _selectDate(context, false),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'To Date',
                          prefixIcon: Icon(Icons.calendar_today),
                          suffixIcon: Icon(Icons.arrow_drop_down),
                        ),
                        child: Text(
                          _toDate == null
                              ? 'Select date'
                              : DateFormat('MMM dd, yyyy').format(_toDate!),
                        ),
                      ),
                    ),

                    if (_totalDays > 0) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Total: $_totalDays day${_totalDays > 1 ? 's' : ''}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),

                    // Reason
                    TextFormField(
                      controller: _reasonController,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Reason',
                        hintText: 'Enter reason for leave...',
                        alignLabelWithHint: true,
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a reason';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Attach Document
                    OutlinedButton.icon(
                      onPressed: _showAttachmentPicker,
                      icon: const Icon(Icons.attach_file),
                      label: const Text('Attach Document (Optional)'),
                    ),
                    if (_attachments.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _attachments
                            .map(
                              (file) => Chip(
                                label: Text(file),
                                onDeleted: () {
                                  setState(() {
                                    _attachments.remove(file);
                                  });
                                },
                              ),
                            )
                            .toList(),
                      ),
                    ],
                    const SizedBox(height: 24),

                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _submitRequest,
                        child: const Text(
                          'SUBMIT REQUEST',
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
            ),
            const SizedBox(height: 24),

            // Pending Requests
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Recent Requests', style: AppTheme.heading3),
                      TextButton(
                        onPressed: () {},
                        child: const Text('View All'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_isLoadingRequests)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: leaveRequests.length,
                      itemBuilder: (context, index) {
                        final request = leaveRequests[index];
                        Color statusColor;
                        IconData statusIcon;

                        switch (request['status']) {
                          case 'approved':
                            statusColor = AppTheme.successColor;
                            statusIcon = Icons.check_circle;
                            break;
                          case 'rejected':
                            statusColor = AppTheme.errorColor;
                            statusIcon = Icons.cancel;
                            break;
                          default:
                            statusColor = AppTheme.warningColor;
                            statusIcon = Icons.pending;
                        }

                        return Card(
                          child: ListTile(
                            leading: Icon(
                              statusIcon,
                              color: statusColor,
                              size: 32,
                            ),
                            title: Text(
                              request['leaveType']?.toString() ?? 'Leave',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Text(
                                  request['reason']?.toString() ??
                                      'No reason provided.',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  '${request['fromDate']} - ${request['toDate']}',
                                ),
                                Text(
                                  '${request['days']} day${request['days'] > 1 ? 's' : ''}',
                                ),
                              ],
                            ),
                            trailing: Chip(
                              label: Text(
                                request['status'].toString().toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              backgroundColor: statusColor,
                              padding: EdgeInsets.zero,
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildLeaveBalance(String type, int days) {
    return Column(
      children: [
        Text(
          '$days',
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(type, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );
  }

  Future<void> _loadLeaveRequests() async {
    final userId = _userContext.userId;
    if (userId == null || userId.isEmpty) {
      return;
    }

    setState(() {
      _isLoadingRequests = true;
    });

    try {
      debugPrint(
        '[LeaveRequestScreen] Fetching leave requests for userId: $userId',
      );
      final response = await _apiClient.get('/api/leave/$userId');
      debugPrint(
        '[LeaveRequestScreen] API Response status: ${response.statusCode}',
      );
      if (response.statusCode == 200) {
        debugPrint('[LeaveRequestScreen] API Response body: ${response.body}');
        final list = List<Map<String, dynamic>>.from(
          jsonDecode(response.body) as List<dynamic>,
        );
        debugPrint('[LeaveRequestScreen] Parsed ${list.length} leave requests');
        final mapped = list.map((item) {
          debugPrint('[LeaveRequestScreen] Processing item: $item');
          final data = (item['data'] as Map<String, dynamic>? ?? item);
          final start = _parseDate(data['startDateUtc']);
          final end = _parseDate(data['endDateUtc']);
          final days = start != null && end != null
              ? end.difference(start).inDays + 1
              : 0;
          return {
            'reason': data['reason'] ?? 'Leave Request',
            'leaveType': data['leaveType'] ?? 'Leave',
            'fromDate': start == null
                ? '-'
                : DateFormat('MMM dd, yyyy').format(start),
            'toDate': end == null
                ? '-'
                : DateFormat('MMM dd, yyyy').format(end),
            'days': days,
            'status': item.containsKey('status')
                ? (item['status'] ?? 'pending')
                : (data['status'] ?? 'pending'),
          };
        }).toList();

        debugPrint(
          '[LeaveRequestScreen] Mapped ${mapped.length} leave requests for UI',
        );
        setState(() {
          _leaveRequests
            ..clear()
            ..addAll(mapped);
        });
      } else {
        debugPrint(
          '[LeaveRequestScreen] API returned status: ${response.statusCode}',
        );
        debugPrint('[LeaveRequestScreen] Response body: ${response.body}');
      }
    } catch (e, st) {
      debugPrint('[LeaveRequestScreen] Error loading leave requests: $e');
      debugPrint('$st');
      // Ignore load errors.
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingRequests = false;
        });
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
}
