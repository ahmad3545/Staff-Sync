import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fyp/services/auth_service.dart';
import 'package:fyp/services/api_client.dart';
import 'package:fyp/services/user_context.dart';
import 'package:fyp/utils/app_theme.dart';
import 'package:fyp/utils/byte_downloader.dart';
import 'package:intl/intl.dart';

class PayrollScreen extends StatefulWidget {
  const PayrollScreen({super.key});

  @override
  State<PayrollScreen> createState() => _PayrollScreenState();
}

class _PayrollScreenState extends State<PayrollScreen> {
  String? _selectedMonth;
  final List<String> _months = [];
  final List<Map<String, dynamic>> _history = [];
  final List<Map<String, dynamic>> _users = [];
  Map<String, dynamic>? _currentPayroll;
  bool _isLoading = false;
  bool _isLoadingUsers = false;
  final ApiClient _apiClient = ApiClient();
  final AuthService _authService = AuthService();
  final UserContext _userContext = UserContext();
  String? _selectedUserId;
  String? _selectedUserName;
  DateTime? _joinedAtUtc;
  double _baseSalary = 0;
  double _overtimeRate = 0;
  bool _adminLoaded = false;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _selectedUserId = _userContext.userId;
    _resolveAdminStatus();
    _loadInitialPayrollContext();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Payroll')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSummaryCard(),
            const SizedBox(height: 16),
            _buildBreakdownCard(),
            const SizedBox(height: 16),
            _buildHistoryCard(),
          ],
        ),
      ),
    );
  }

  Future<void> _resolveAdminStatus() async {
    final isAdmin = await _authService.isAdmin();
    if (!mounted) {
      return;
    }
    setState(() {
      _isAdmin = isAdmin;
      _adminLoaded = true;
    });
    if (_selectedUserId != null) {
      await _loadInitialPayrollContext();
    }
  }

  Widget _buildSummaryCard() {
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
            'Payroll Summary',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          if (!_adminLoaded)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else if (_isAdmin) ...[
            _buildEmployeeSelector(),
            const SizedBox(height: 12),
          ],
          if (_joinedAtUtc != null) ...[
            _buildJoinedInfo(),
            const SizedBox(height: 12),
          ],
          if (_isAdmin && _selectedUserId != null) ...[
            _buildBaseSalaryInfo(),
            const SizedBox(height: 12),
          ],
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'Processed',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (_isAdmin) ...[
                OutlinedButton.icon(
                  onPressed: _selectedUserId == null ? null : _showSetPayDialog,
                  icon: const Icon(Icons.payments_outlined),
                  label: const Text('Set Base Salary'),
                ),
                const SizedBox(width: 8),
              ],
              ElevatedButton.icon(
                onPressed: _showCalculateDialog,
                icon: const Icon(Icons.calculate),
                label: const Text('Calculate'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Net Pay',
            style: TextStyle(fontSize: 12, color: Colors.black54),
          ),
          const SizedBox(height: 6),
          Text(
            _currentPayroll?['netPay'] ?? 'PKR 0',
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildMiniStat(
                  'Paid Days',
                  _currentPayroll?['paidDays'] ?? '0',
                  AppTheme.successColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMiniStat(
                  'Leaves',
                  _currentPayroll?['leaveDays'] ?? '0',
                  AppTheme.warningColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMiniStat(
                  'Overtime',
                  _currentPayroll?['overtime'] ?? '0h',
                  Colors.indigo,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildJoinedInfo() {
    final joinedAt = _joinedAtUtc!.toLocal();
    final daysSinceJoin = DateTime.now().difference(joinedAt).inDays + 1;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blueGrey.withOpacity(0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.blueGrey.withOpacity(0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Joined: ${DateFormat('MMM dd, yyyy').format(joinedAt)}',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            '$daysSinceJoin days since joining',
            style: TextStyle(fontSize: 12, color: Colors.grey[700]),
          ),
        ],
      ),
    );
  }

  Widget _buildBaseSalaryInfo() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withOpacity(0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.primaryColor.withOpacity(0.12)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Base Salary',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
              const SizedBox(height: 4),
              Text(
                'PKR ${_baseSalary.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          TextButton.icon(
            onPressed: _showSetPayDialog,
            icon: const Icon(Icons.edit),
            label: const Text('Change'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmployeeSelector() {
    if (_users.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Text(
          _isLoadingUsers ? 'Loading employees...' : 'No employees found',
          style: TextStyle(color: Colors.grey[700], fontSize: 13),
        ),
      );
    }

    final selectedValue =
        _users.any((user) => user['id']?.toString() == _selectedUserId)
        ? _selectedUserId
        : null;

    return DropdownButtonFormField<String>(
      initialValue: selectedValue,
      decoration: const InputDecoration(labelText: 'Employee'),
      items: _users
          .map(
            (user) => DropdownMenuItem<String>(
              value: user['id']?.toString(),
              child: Text(user['name']?.toString() ?? '-'),
            ),
          )
          .toList(),
      onChanged: (value) {
        if (value == null || value.isEmpty) {
          return;
        }
        final selectedUser = _users.firstWhere(
          (user) => user['id']?.toString() == value,
          orElse: () => {},
        );
        setState(() {
          _selectedUserId = value;
          _selectedUserName = selectedUser['name']?.toString();
          _joinedAtUtc = selectedUser['joinedAtUtc'] as DateTime?;
        });
        _loadPayrollForUser(value);
      },
    );
  }

  Widget _buildMiniStat(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 10, color: Colors.black54),
          ),
        ],
      ),
    );
  }

  Widget _buildBreakdownCard() {
    final salaryItems =
        _currentPayroll?['breakdown'] as List<Map<String, String>>? ??
        [
          {'label': 'Basic Salary', 'amount': 'PKR 0'},
          {'label': 'Allowances', 'amount': 'PKR 0'},
          {'label': 'Deductions', 'amount': '-PKR 0'},
          {'label': 'Overtime', 'amount': 'PKR 0'},
        ];
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
            'Salary Breakdown',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          ...salaryItems.map(
            (item) => _buildAmountRow(item['label']!, item['amount']!),
          ),
        ],
      ),
    );
  }

  Widget _buildAmountRow(String label, String amount) {
    final isNegative = amount.startsWith('-');
    final color = isNegative ? AppTheme.errorColor : Colors.black87;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13)),
          Text(
            amount,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryCard() {
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
            'Payroll History',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else if (_history.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'No payroll records found.\nCreate one using Calculate button.',
                style: TextStyle(color: Colors.grey, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            )
          else
            ..._history.map(_buildHistoryRow),
        ],
      ),
    );
  }

  Widget _buildHistoryRow(Map<String, dynamic> item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item['month']?.toString() ?? '-',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                item['status']?.toString() ?? '-',
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              ),
            ],
          ),
          Text(
            item['amount']?.toString() ?? '-',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: () {
              final payrollId = item['id']?.toString();
              if (payrollId == null || payrollId.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Payroll id missing')),
                );
                return;
              }
              _downloadPayslip(payrollId);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _loadInitialPayrollContext() async {
    if (_adminLoaded && _isAdmin) {
      await _loadUsers();
    }

    final userId = _selectedUserId ?? _userContext.userId;
    if (userId != null && userId.isNotEmpty) {
      await _loadPayrollForUser(userId);
    }
  }

  Future<void> _loadUsers() async {
    setState(() {
      _isLoadingUsers = true;
    });

    try {
      final response = await _apiClient.get('/api/users');
      if (response.statusCode == 200) {
        final list = List<Map<String, dynamic>>.from(
          jsonDecode(response.body) as List<dynamic>,
        );
        final mapped = list
            .where((item) => item['id']?.toString().isNotEmpty == true)
            .map((item) {
              final data = item['data'] as Map<String, dynamic>? ?? {};
              final role = data['role']?.toString().toLowerCase();
              if (role != 'employee') {
                return null;
              }

              return {
                'id': item['id'],
                'name':
                    data['fullName']?.toString() ??
                    item['id']?.toString() ??
                    '-',
                'baseSalary': _toDouble(data['baseSalary']),
                'overtimeRate': _toDouble(data['overtimeRate']),
                'joinedAtUtc': _parseDate(data['createdAtUtc']),
              };
            })
            .whereType<Map<String, dynamic>>()
            .toList();

        setState(() {
          _users
            ..clear()
            ..addAll(mapped);
          final hasSelectedUser = _users.any(
            (user) => user['id']?.toString() == _selectedUserId,
          );
          if ((!hasSelectedUser || _selectedUserId == null) &&
              _users.isNotEmpty) {
            _selectedUserId = _users.first['id']?.toString();
            _selectedUserName = _users.first['name']?.toString();
            _joinedAtUtc = _users.first['joinedAtUtc'] as DateTime?;
          }
        });
      }
    } catch (e) {
      debugPrint('Payroll: loadUsers exception=$e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingUsers = false;
        });
      }
    }
  }

  Future<void> _loadPayrollForUser(String userId) async {
    debugPrint('Payroll: Loading for userId=$userId');
    setState(() {
      _isLoading = true;
    });

    try {
      await _loadPayrollSettings(userId);

      final response = await _apiClient.get('/api/payroll/$userId');
      debugPrint(
        'Payroll: Response status=${response.statusCode}, body=${response.body}',
      );

      if (response.statusCode == 200) {
        final body = response.body;
        if (body.isEmpty) {
          setState(() {
            _history.clear();
            _months.clear();
            _selectedMonth = null;
            _currentPayroll = null;
          });
          return;
        }

        final list = List<Map<String, dynamic>>.from(
          jsonDecode(body) as List<dynamic>,
        );

        final formatter = DateFormat('MMMM yyyy');
        final mapped = list.map((item) {
          final data = item['data'] as Map<String, dynamic>? ?? {};
          final periodStart = _parseDate(data['periodStartUtc']);
          final periodEnd = _parseDate(data['periodEndUtc']);
          final monthLabel = periodStart == null
              ? 'Unknown'
              : formatter.format(periodStart);
          final base = (data['baseSalary'] ?? _baseSalary).toString();
          final allowances = (data['allowances'] ?? 0).toString();
          final deductions = (data['deductions'] ?? 0).toString();
          final overtimeHours = (data['overtimeHours'] ?? 0).toString();
          final overtimeRate = (data['overtimeRate'] ?? _overtimeRate)
              .toString();
          final net = (data['netSalary'] ?? 0).toString();

          return {
            'id': item['id'],
            'month': monthLabel,
            'status': data['status'] ?? 'processed',
            'amount': 'PKR $net',
            'netPay': 'PKR $net',
            'paidDays': '0',
            'leaveDays': '0',
            'overtime': '${overtimeHours}h',
            'breakdown': [
              {'label': 'Basic Salary', 'amount': 'PKR $base'},
              {'label': 'Allowances', 'amount': 'PKR $allowances'},
              {'label': 'Deductions', 'amount': '-PKR $deductions'},
              {
                'label': 'Overtime',
                'amount':
                    'PKR ${_calculateOvertime(overtimeHours, overtimeRate)}',
              },
            ],
            'period': '${_formatDate(periodStart)} - ${_formatDate(periodEnd)}',
          };
        }).toList();

        setState(() {
          _history
            ..clear()
            ..addAll(mapped);
          _months
            ..clear()
            ..addAll(mapped.map((item) => item['month'] as String));
          if (_months.isNotEmpty) {
            _selectedMonth ??= _months.first;
            _currentPayroll = _history.first;
          }
        });
      } else if (response.statusCode == 404) {
        setState(() {
          _history.clear();
          _months.clear();
          _selectedMonth = null;
          _currentPayroll = null;
        });
      } else {
        debugPrint('Payroll: Error ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Payroll: Exception=$e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadPayrollSettings(String userId) async {
    try {
      final response = await _apiClient.get('/api/users/$userId');
      if (response.statusCode != 200) {
        return;
      }

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final data = body['data'] as Map<String, dynamic>? ?? {};
      setState(() {
        _baseSalary = _toDouble(data['baseSalary']);
        _overtimeRate = _toDouble(data['overtimeRate']);
        _selectedUserName = data['fullName']?.toString() ?? _selectedUserName;
        _joinedAtUtc = _parseDate(data['createdAtUtc']) ?? _joinedAtUtc;
      });
    } catch (e) {
      debugPrint('Payroll: loadSettings exception=$e');
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

  double _toDouble(dynamic value) {
    if (value == null) {
      return 0;
    }
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value.toString()) ?? 0;
  }

  Future<void> _showCalculateDialog() async {
    final targetUserId = _selectedUserId ?? _userContext.userId;
    if (targetUserId == null || targetUserId.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Select an employee first')));
      return;
    }

    final baseController = TextEditingController(
      text: _baseSalary > 0 ? _baseSalary.toStringAsFixed(0) : '0',
    );
    final overtimeHoursController = TextEditingController(text: '0');
    final joinDate = (_joinedAtUtc ?? DateTime.now()).toUtc();
    final periodStartUtc = joinDate;
    final periodEndUtc = DateTime.now().toUtc();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            _isAdmin ? 'Calculate Payroll' : 'Generate Salary Report',
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: TextEditingController(
                    text: _selectedUserName ?? targetUserId,
                  ),
                  readOnly: true,
                  decoration: const InputDecoration(labelText: 'Employee'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: baseController,
                  readOnly: true,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Base Salary'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: overtimeHoursController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Overtime Hours',
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blueGrey.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'Overtime rate is fixed at PKR 2000.',
                    style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                  ),
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Payroll runs from joining date to today',
                    style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final payload = {
                  'userId': targetUserId,
                  'periodStartUtc': periodStartUtc.toIso8601String(),
                  'periodEndUtc': periodEndUtc.toIso8601String(),
                  'baseSalary':
                      double.tryParse(baseController.text) ?? _baseSalary,
                  'allowances': 0,
                  'deductions': 0,
                  'overtimeHours':
                      double.tryParse(overtimeHoursController.text) ?? 0,
                  'overtimeRate': 2000,
                };

                Navigator.pop(dialogContext);
                try {
                  final resp = await _apiClient.postJson(
                    '/api/payroll/calculate',
                    payload,
                  );
                  if (resp.statusCode == 200) {
                    final responseData = resp.body.isEmpty
                        ? <String, dynamic>{}
                        : (jsonDecode(resp.body) as Map<String, dynamic>);
                    final baseSalary =
                        double.tryParse(baseController.text) ?? _baseSalary;
                    final overtimeHours =
                        double.tryParse(overtimeHoursController.text) ?? 0;
                    final overtimePay = overtimeHours * 2000;
                    final netSalary = _calculateNetSalary(
                      baseSalary,
                      overtimePay,
                    );
                    final periodLabel = DateFormat(
                      'MMMM yyyy',
                    ).format(joinDate);

                    _applyCalculatedPayrollLocally(
                      payrollId: responseData['id']?.toString(),
                      periodLabel: periodLabel,
                      baseSalary: baseSalary,
                      overtimeHours: overtimeHours,
                      overtimePay: overtimePay,
                      netSalary: responseData['netSalary'] is num
                          ? (responseData['netSalary'] as num).toDouble()
                          : netSalary,
                      periodStartUtc: periodStartUtc,
                      periodEndUtc: periodEndUtc,
                    );
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Payroll calculated')),
                      );
                    }
                  } else if (resp.statusCode == 403) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Not authorized')),
                      );
                    }
                  } else {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Failed: ${resp.statusCode} ${resp.body}',
                          ),
                        ),
                      );
                    }
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text('Error: $e')));
                  }
                }
              },
              child: const Text('Calculate'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showSetPayDialog() async {
    final targetUserId = _selectedUserId ?? _userContext.userId;
    if (targetUserId == null || targetUserId.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Select an employee first')));
      return;
    }

    final baseController = TextEditingController(
      text: _baseSalary > 0 ? _baseSalary.toStringAsFixed(0) : '0',
    );

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Set Base Salary'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: baseController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Base Salary (PKR)'),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blueGrey.withOpacity(0.06),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text('Overtime rate is fixed at PKR 2000.'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final baseSalary = double.tryParse(baseController.text) ?? 0;
              Navigator.pop(dialogContext);
              try {
                final response = await _apiClient.postJson(
                  '/api/admin/payroll-settings',
                  {'userId': targetUserId, 'baseSalary': baseSalary},
                );

                if (response.statusCode == 200) {
                  setState(() {
                    _baseSalary = baseSalary;
                    final userIndex = _users.indexWhere(
                      (user) => user['id']?.toString() == targetUserId,
                    );
                    if (userIndex != -1) {
                      _users[userIndex] = {
                        ..._users[userIndex],
                        'baseSalary': baseSalary,
                      };
                    }
                  });
                  await _loadPayrollSettings(targetUserId);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Payroll settings saved')),
                    );
                  }
                } else {
                  if (mounted) {
                    final failureMessage = response.body.isEmpty
                        ? 'Save failed. Please try again.'
                        : response.body.split('\n').first;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Save failed: ${response.statusCode} $failureMessage',
                        ),
                      ),
                    );
                  }
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error saving pay settings: $e')),
                  );
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _applyCalculatedPayrollLocally({
    required String? payrollId,
    required String periodLabel,
    required double baseSalary,
    required double overtimeHours,
    required double overtimePay,
    required double netSalary,
    required DateTime periodStartUtc,
    required DateTime periodEndUtc,
  }) {
    final item = {
      'id': payrollId ?? DateTime.now().millisecondsSinceEpoch.toString(),
      'month': periodLabel,
      'status': 'processed',
      'amount': 'PKR ${netSalary.toStringAsFixed(0)}',
      'netPay': 'PKR ${netSalary.toStringAsFixed(0)}',
      'paidDays': '0',
      'leaveDays': '0',
      'overtime': '${overtimeHours.toStringAsFixed(0)}h',
      'breakdown': [
        {
          'label': 'Basic Salary',
          'amount': 'PKR ${baseSalary.toStringAsFixed(0)}',
        },
        {'label': 'Allowances', 'amount': 'PKR 0'},
        {'label': 'Deductions', 'amount': '-PKR 0'},
        {
          'label': 'Overtime',
          'amount': 'PKR ${overtimePay.toStringAsFixed(0)}',
        },
      ],
      'period':
          '${_formatDate(periodStartUtc.toLocal())} - ${_formatDate(periodEndUtc.toLocal())}',
    };

    setState(() {
      _history.insert(0, item);
      _months
        ..clear()
        ..addAll(_history.map((entry) => entry['month'] as String));
      _selectedMonth = item['month'] as String;
      _currentPayroll = item;
    });
  }

  double _calculateNetSalary(double baseSalary, double overtimePay) {
    final netSalary = baseSalary + overtimePay;
    return netSalary < 0 ? 0 : netSalary;
  }

  Future<void> _downloadPayslip(String payrollId) async {
    try {
      final resp = await _apiClient.get(
        '/api/payroll/payslip/$payrollId',
        query: {'format': 'pdf'},
      );
      if (resp.statusCode != 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to fetch payslip: ${resp.statusCode}'),
          ),
        );
        return;
      }

      final bytes = resp.bodyBytes;
      final fileName = 'payslip_$payrollId.pdf';
      final saved = await downloadBytes(fileName, bytes);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            kIsWeb ? 'Download started: $fileName' : 'Saved to $saved',
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error downloading payslip')),
      );
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) {
      return '-';
    }
    return DateFormat('MMM dd, yyyy').format(date);
  }

  String _calculateOvertime(String hours, String rate) {
    final parsedHours = double.tryParse(hours) ?? 0;
    final parsedRate = double.tryParse(rate) ?? 0;
    return (parsedHours * parsedRate).toStringAsFixed(0);
  }
}
