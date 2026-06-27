import 'package:flutter/material.dart';
import 'package:fyp/constants/app_constants.dart';
import 'package:fyp/services/geofence_monitor.dart';
import 'package:fyp/utils/app_theme.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GeofenceSettingsScreen extends StatefulWidget {
  const GeofenceSettingsScreen({super.key});

  @override
  State<GeofenceSettingsScreen> createState() => _GeofenceSettingsScreenState();
}

class _GeofenceSettingsScreenState extends State<GeofenceSettingsScreen> {
  double _radiusMeters = AppConstants.geofenceDefaultRadius;
  bool _autoAlerts = true;
  bool _monitoringEnabled = false;
  final _siteNameController = TextEditingController();
  final _siteAddressController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSettings();
    GeofenceMonitor.instance.loadSettings();
  }

  @override
  void dispose() {
    _siteNameController.dispose();
    _siteAddressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Geofence Settings')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoCard(),
            const SizedBox(height: 16),
            _buildRadiusCard(),
            const SizedBox(height: 16),
            _buildStatusCard(),
            const SizedBox(height: 16),
            _buildActions(),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
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
            'Site Details',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _siteNameController,
            decoration: const InputDecoration(
              labelText: 'Site Name',
              prefixIcon: Icon(Icons.business_outlined),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _siteAddressController,
            decoration: const InputDecoration(
              labelText: 'Address',
              prefixIcon: Icon(Icons.location_on_outlined),
            ),
          ),
          const SizedBox(height: 12),
          _buildInfoRow(
            'Latitude',
            AppConstants.geofenceSiteLat.toStringAsFixed(4),
          ),
          _buildInfoRow(
            'Longitude',
            AppConstants.geofenceSiteLon.toStringAsFixed(4),
          ),
          const SizedBox(height: 8),
          Text(
            'Map is not enabled yet. Configure Google Maps in Phase-II.',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildRadiusCard() {
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
            'Allowed Radius',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${_radiusMeters.toStringAsFixed(0)} meters',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(height: 8),
          Slider(
            value: _radiusMeters,
            min: 50,
            max: 500,
            divisions: 9,
            label: '${_radiusMeters.toStringAsFixed(0)}m',
            onChanged: (value) {
              setState(() {
                _radiusMeters = value;
              });
            },
          ),
          const SizedBox(height: 8),
          Text(
            'Employees outside this radius will be marked as out of site.',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard() {
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
            'Detection Status',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          ValueListenableBuilder<GeofenceSnapshot>(
            valueListenable: GeofenceMonitor.instance.status,
            builder: (context, snapshot, _) {
              final inside = snapshot.isInside;
              final label = inside ? 'Inside Zone' : 'Outside Zone';
              final color = inside
                  ? AppTheme.successColor
                  : AppTheme.errorColor;
              final lastCheck = snapshot.lastCheck;
              final timeText = lastCheck == null
                  ? 'Never'
                  : DateFormat('hh:mm a').format(lastCheck);

              return Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Last check: $timeText',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Enable Geofencing'),
            subtitle: const Text('Monitor location in background'),
            value: _monitoringEnabled,
            onChanged: (value) {
              setState(() {
                _monitoringEnabled = value;
              });
            },
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Auto Attendance Alerts'),
            subtitle: const Text('Notify admin when staff leaves site'),
            value: _autoAlerts,
            onChanged: (value) {
              setState(() {
                _autoAlerts = value;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildActions() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () {
              setState(() {
                _radiusMeters = AppConstants.geofenceDefaultRadius;
                _autoAlerts = true;
                _monitoringEnabled = false;
                _siteNameController.text = AppConstants.geofenceSiteName;
                _siteAddressController.text = AppConstants.geofenceSiteAddress;
              });
              _saveSiteDetails();
              GeofenceMonitor.instance.updateSettings(
                radiusMeters: _radiusMeters,
                autoAlerts: _autoAlerts,
                enabled: _monitoringEnabled,
              );
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Settings reset')));
            },
            child: const Text('Reset'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            onPressed: () {
              _saveSiteDetails();
              GeofenceMonitor.instance.updateSettings(
                radiusMeters: _radiusMeters,
                autoAlerts: _autoAlerts,
                enabled: _monitoringEnabled,
              );
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Geofence settings saved')),
              );
            },
            child: const Text('Save Settings'),
          ),
        ),
      ],
    );
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _radiusMeters =
          prefs.getDouble('geofence_radius') ??
          AppConstants.geofenceDefaultRadius;
      _autoAlerts = prefs.getBool('geofence_auto_alerts') ?? true;
      _monitoringEnabled = prefs.getBool('geofence_enabled') ?? false;
      _siteNameController.text =
          prefs.getString('geofence_site_name') ??
          AppConstants.geofenceSiteName;
      _siteAddressController.text =
          prefs.getString('geofence_site_address') ??
          AppConstants.geofenceSiteAddress;
    });
  }

  Future<void> _saveSiteDetails() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'geofence_site_name',
      _siteNameController.text.trim().isEmpty
          ? AppConstants.geofenceSiteName
          : _siteNameController.text.trim(),
    );
    await prefs.setString(
      'geofence_site_address',
      _siteAddressController.text.trim().isEmpty
          ? AppConstants.geofenceSiteAddress
          : _siteAddressController.text.trim(),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }
}
