import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:fyp/services/api_client.dart';
import 'package:fyp/utils/app_theme.dart';

class StaffManagementScreen extends StatefulWidget {
  const StaffManagementScreen({super.key});

  @override
  State<StaffManagementScreen> createState() => _StaffManagementScreenState();
}

class _StaffManagementScreenState extends State<StaffManagementScreen> {
  String _selectedRole = 'All';
  final List<String> _roles = const ['All', 'Admin', 'Manager', 'Employee'];
  final List<Map<String, dynamic>> _staff = [];
  bool _isLoading = false;
  final ApiClient _apiClient = ApiClient();

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _departmentController = TextEditingController();
  String _newRole = 'Employee';
  bool _isCreating = false;

  @override
  void initState() {
    super.initState();
    _loadStaff();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _departmentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filteredStaff = _selectedRole == 'All'
        ? _staff
        : _staff.where((member) => member['role'] == _selectedRole).toList();
    final totalStaff = _staff.length;
    final activeStaff = _staff
        .where((member) => member['status'] == 'Active')
        .length;
    final inactiveStaff = totalStaff - activeStaff;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Staff Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              _showAddStaffDialog();
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
            _buildSummaryRow(
              total: totalStaff,
              active: activeStaff,
              inactive: inactiveStaff,
            ),
            const SizedBox(height: 12),
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else
              ...filteredStaff.map(_buildStaffCard),
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
            'Filter Staff',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _selectedRole,
            items: _roles
                .map((role) => DropdownMenuItem(value: role, child: Text(role)))
                .toList(),
            onChanged: (value) {
              if (value == null) {
                return;
              }
              setState(() {
                _selectedRole = value;
              });
            },
            decoration: const InputDecoration(labelText: 'Role'),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow({
    required int total,
    required int active,
    required int inactive,
  }) {
    return Row(
      children: [
        Expanded(
          child: _buildSummaryCard(
            'Total Staff',
            '$total',
            AppTheme.primaryColor,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildSummaryCard('Active', '$active', AppTheme.successColor),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildSummaryCard(
            'Inactive',
            '$inactive',
            AppTheme.errorColor,
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(String label, String value, Color color) {
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

  Widget _buildStaffCard(Map<String, dynamic> staff) {
    final status = staff['status']?.toString() ?? 'Active';
    final statusColor = status.toLowerCase() == 'active'
        ? AppTheme.successColor
        : AppTheme.errorColor;

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
          CircleAvatar(
            backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
            child: Text(
              (staff['name']?.toString() ?? 'U').substring(0, 1),
              style: const TextStyle(color: AppTheme.primaryColor),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  staff['name']?.toString() ?? '-',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${staff['role'] ?? '-'} • ${staff['dept'] ?? '-'}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                const SizedBox(height: 4),
                Text(
                  staff['id']?.toString() ?? '-',
                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
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
              const SizedBox(height: 6),
              TextButton(
                onPressed: () => _openStaffProfileScreen(staff),
                child: const Text('View'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _openStaffProfileScreen(Map<String, dynamic> staff) async {
    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (context) => StaffProfileScreen(staff: staff)),
    );

    if (updated == true && mounted) {
      await _loadStaff();
    }
  }

  Future<void> _showStaffProfileDialog(Map<String, dynamic> staff) async {
    final id = staff['id']?.toString() ?? '';
    final nameController = TextEditingController(
      text: staff['name']?.toString() ?? '',
    );
    final emailController = TextEditingController(
      text: staff['email']?.toString() ?? '',
    );
    final phoneController = TextEditingController(
      text: staff['phone']?.toString() ?? '',
    );
    final departmentController = TextEditingController(
      text: staff['dept']?.toString() ?? '',
    );
    var selectedRole = staff['role']?.toString() ?? 'Employee';
    var isSaving = false;
    var isDeleting = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Staff Profile'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: 'Full Name'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(labelText: 'Email'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(labelText: 'Phone'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: departmentController,
                      decoration: const InputDecoration(
                        labelText: 'Department',
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: selectedRole,
                      items: const [
                        DropdownMenuItem(
                          value: 'Employee',
                          child: Text('Employee'),
                        ),
                        DropdownMenuItem(
                          value: 'Manager',
                          child: Text('Manager'),
                        ),
                        DropdownMenuItem(value: 'Admin', child: Text('Admin')),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            selectedRole = value;
                          });
                        }
                      },
                      decoration: const InputDecoration(labelText: 'Role'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving || isDeleting
                      ? null
                      : () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
                TextButton(
                  onPressed: isDeleting || isSaving
                      ? null
                      : () async {
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Delete Staff'),
                              content: const Text(
                                'Are you sure you want to delete this staff member? This cannot be undone.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, false),
                                  child: const Text('Cancel'),
                                ),
                                ElevatedButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text('Delete'),
                                ),
                              ],
                            ),
                          );
                          if (confirmed != true) {
                            return;
                          }
                          setState(() {
                            isDeleting = true;
                          });
                          final success = await _deleteStaff(id);
                          setState(() {
                            isDeleting = false;
                          });
                          if (success) {
                            if (mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(this.context).showSnackBar(
                                const SnackBar(content: Text('Staff deleted.')),
                              );
                              await _loadStaff();
                            }
                          }
                        },
                  child: isDeleting
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Delete'),
                ),
                ElevatedButton(
                  onPressed: isSaving || isDeleting
                      ? null
                      : () async {
                          setState(() {
                            isSaving = true;
                          });
                          final success = await _updateStaffProfile(
                            id,
                            nameController.text.trim(),
                            emailController.text.trim(),
                            phoneController.text.trim(),
                            departmentController.text.trim(),
                            selectedRole,
                          );
                          setState(() {
                            isSaving = false;
                          });
                          if (success) {
                            if (mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(this.context).showSnackBar(
                                const SnackBar(
                                  content: Text('Staff profile updated.'),
                                ),
                              );
                              await _loadStaff();
                            }
                          }
                        },
                  child: isSaving
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<bool> _updateStaffProfile(
    String userId,
    String fullName,
    String email,
    String phone,
    String departmentId,
    String role,
  ) async {
    try {
      final response = await _apiClient.postJson('/api/users/profile', {
        'userId': userId,
        'fullName': fullName.isEmpty ? null : fullName,
        'email': email.isEmpty ? null : email,
        'phone': phone.isEmpty ? null : phone,
        'departmentId': departmentId.isEmpty ? null : departmentId,
        'role': role.toLowerCase(),
      });
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _deleteStaff(String userId) async {
    try {
      final response = await _apiClient.delete('/api/users/$userId');
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
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
            'dept': data['departmentId'] ?? '-',
            'email': data['email'] ?? '-',
            'phone': data['phone'] ?? '-',
            'status': 'Active',
          };
        }).toList();

        setState(() {
          _staff
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

  void _showAddStaffDialog() {
    _nameController.clear();
    _emailController.clear();
    _phoneController.clear();
    _passwordController.clear();
    _departmentController.clear();
    _newRole = 'Employee';

    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Staff'),
        content: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Full Name'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Phone'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Temporary Password',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _departmentController,
                decoration: const InputDecoration(labelText: 'Department'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _newRole,
                items: const [
                  DropdownMenuItem(value: 'Employee', child: Text('Employee')),
                  DropdownMenuItem(value: 'Manager', child: Text('Manager')),
                  DropdownMenuItem(value: 'Admin', child: Text('Admin')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    _newRole = value;
                  }
                },
                decoration: const InputDecoration(labelText: 'Role'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: _isCreating ? null : () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: _isCreating ? null : _createStaff,
            child: _isCreating
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Create'),
          ),
        ],
      ),
    );
  }

  Future<void> _createStaff() async {
    if (_emailController.text.trim().isEmpty ||
        _passwordController.text.trim().length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Email and password required.')),
      );
      return;
    }

    setState(() {
      _isCreating = true;
    });

    final payload = {
      'email': _emailController.text.trim(),
      'password': _passwordController.text.trim(),
      'fullName': _nameController.text.trim().isEmpty
          ? null
          : _nameController.text.trim(),
      'phone': _phoneController.text.trim().isEmpty
          ? null
          : _phoneController.text.trim(),
      'departmentId': _departmentController.text.trim().isEmpty
          ? null
          : _departmentController.text.trim(),
      'role': _newRole.toLowerCase(),
    };

    try {
      final response = await _apiClient.postJson('/api/admin/users', payload);
      if (response.statusCode != 200) {
        final message = response.body.isNotEmpty
            ? response.body
            : 'Status ${response.statusCode}';
        throw Exception(message);
      }
      if (!mounted) {
        return;
      }
      Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Staff account created.')));
      await _loadStaff();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to create staff: $error'),
          backgroundColor: AppTheme.warningColor,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isCreating = false;
        });
      }
    }
  }
}

class StaffProfileScreen extends StatefulWidget {
  final Map<String, dynamic> staff;

  const StaffProfileScreen({super.key, required this.staff});

  @override
  State<StaffProfileScreen> createState() => _StaffProfileScreenState();
}

class _StaffProfileScreenState extends State<StaffProfileScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  late final TextEditingController _departmentController;
  late String _selectedRole;
  bool _isSaving = false;
  bool _isDeleting = false;
  final ApiClient _apiClient = ApiClient();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.staff['name']?.toString() ?? '',
    );
    _emailController = TextEditingController(
      text: widget.staff['email']?.toString() ?? '',
    );
    _phoneController = TextEditingController(
      text: widget.staff['phone']?.toString() ?? '',
    );
    _departmentController = TextEditingController(
      text: widget.staff['dept']?.toString() ?? '',
    );
    _selectedRole = widget.staff['role']?.toString() ?? 'Employee';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _departmentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Staff Profile')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'User ID: ${widget.staff['id'] ?? '-'}',
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Full Name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Phone'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _departmentController,
              decoration: const InputDecoration(labelText: 'Department'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _selectedRole,
              items: const [
                DropdownMenuItem(value: 'Employee', child: Text('Employee')),
                DropdownMenuItem(value: 'Manager', child: Text('Manager')),
                DropdownMenuItem(value: 'Admin', child: Text('Admin')),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedRole = value;
                  });
                }
              },
              decoration: const InputDecoration(labelText: 'Role'),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _saveProfile,
                    child: _isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Save'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isDeleting ? null : _confirmDelete,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.errorColor,
                    ),
                    child: _isDeleting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Delete'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveProfile() async {
    setState(() {
      _isSaving = true;
    });

    final userId = widget.staff['id']?.toString() ?? '';
    final response = await _apiClient.postJson('/api/users/profile', {
      'userId': userId,
      'fullName': _nameController.text.trim().isEmpty
          ? null
          : _nameController.text.trim(),
      'email': _emailController.text.trim().isEmpty
          ? null
          : _emailController.text.trim(),
      'phone': _phoneController.text.trim().isEmpty
          ? null
          : _phoneController.text.trim(),
      'departmentId': _departmentController.text.trim().isEmpty
          ? null
          : _departmentController.text.trim(),
      'role': _selectedRole.toLowerCase(),
    });

    setState(() {
      _isSaving = false;
    });

    if (response.statusCode == 200) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Staff profile updated.')));
      Navigator.pop(context, true);
      return;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Failed to update staff: ${response.statusCode}'),
        backgroundColor: AppTheme.warningColor,
      ),
    );
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Staff'),
        content: const Text(
          'Are you sure you want to delete this staff member? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _deleteProfile();
    }
  }

  Future<void> _deleteProfile() async {
    setState(() {
      _isDeleting = true;
    });

    final userId = widget.staff['id']?.toString() ?? '';
    final response = await _apiClient.delete('/api/users/$userId');

    setState(() {
      _isDeleting = false;
    });

    if (response.statusCode == 200) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Staff deleted.')));
      Navigator.pop(context, true);
      return;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Failed to delete staff: ${response.statusCode}'),
        backgroundColor: AppTheme.warningColor,
      ),
    );
  }
}
