import 'package:flutter/material.dart';
import 'package:fyp/utils/app_theme.dart';

class SystemSettingsScreen extends StatefulWidget {
  const SystemSettingsScreen({super.key});

  @override
  State<SystemSettingsScreen> createState() => _SystemSettingsScreenState();
}

class _SystemSettingsScreenState extends State<SystemSettingsScreen> {
  bool _requireSelfie = true;
  bool _enableLocation = true;
  bool _autoCheckout = false;
  bool _overtimeApproval = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('System Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Attendance Rules', style: AppTheme.heading3),
          const SizedBox(height: 8),
          Card(
            child: SwitchListTile(
              title: const Text('Require selfie check-in'),
              subtitle: const Text('Capture a selfie on every check-in'),
              value: _requireSelfie,
              onChanged: (value) => setState(() => _requireSelfie = value),
            ),
          ),
          Card(
            child: SwitchListTile(
              title: const Text('Enable location tracking'),
              subtitle: const Text('Use GPS for attendance verification'),
              value: _enableLocation,
              onChanged: (value) => setState(() => _enableLocation = value),
            ),
          ),
          Card(
            child: SwitchListTile(
              title: const Text('Auto-checkout after shift'),
              subtitle: const Text('Ends shifts automatically if user forgets'),
              value: _autoCheckout,
              onChanged: (value) => setState(() => _autoCheckout = value),
            ),
          ),
          const SizedBox(height: 16),
          Text('Approvals', style: AppTheme.heading3),
          const SizedBox(height: 8),
          Card(
            child: SwitchListTile(
              title: const Text('Overtime requires approval'),
              subtitle: const Text('Managers must approve overtime hours'),
              value: _overtimeApproval,
              onChanged: (value) => setState(() => _overtimeApproval = value),
            ),
          ),
          const SizedBox(height: 16),
          Text('Maintenance', style: AppTheme.heading3),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.backup_outlined),
              title: const Text('Backup data'),
              subtitle: const Text('Last backup: Apr 18, 2026'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Backup started.')),
                );
              },
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.restore_outlined),
              title: const Text('Restore defaults'),
              subtitle: const Text('Reset all system settings'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                showDialog<void>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Restore defaults'),
                    content: const Text('Restore settings to default values?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _requireSelfie = true;
                            _enableLocation = true;
                            _autoCheckout = false;
                            _overtimeApproval = true;
                          });
                          Navigator.pop(context);
                        },
                        child: const Text('Restore'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
