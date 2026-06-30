import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:fyp/constants/app_constants.dart';
import 'package:fyp/services/api_client.dart';
import 'package:fyp/services/geofence_monitor.dart';
import 'package:fyp/utils/app_theme.dart';
import 'package:geocoding/geocoding.dart' as geocoding;
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GeofenceSettingsScreen extends StatefulWidget {
  const GeofenceSettingsScreen({super.key});

  @override
  State<GeofenceSettingsScreen> createState() => _GeofenceSettingsScreenState();
}

class _GeofenceSettingsScreenState extends State<GeofenceSettingsScreen> {
  static const _prefSiteLat = 'geofence_site_lat';
  static const _prefSiteLon = 'geofence_site_lon';

  double _radiusMeters = AppConstants.geofenceDefaultRadius;
  bool _autoAlerts = true;
  bool _monitoringEnabled = false;
  bool _isSearching = false;
  bool _isSaving = false;
  GoogleMapController? _mapController;
  LatLng _sitePosition = const LatLng(
    AppConstants.geofenceSiteLat,
    AppConstants.geofenceSiteLon,
  );
  LatLng? _currentPosition;

  final _siteNameController = TextEditingController();
  final _siteAddressController = TextEditingController();
  final _latitudeController = TextEditingController();
  final _longitudeController = TextEditingController();
  final ApiClient _apiClient = ApiClient();

  @override
  void initState() {
    super.initState();
    _loadSettings();
    GeofenceMonitor.instance.loadSettings();
  }

  @override
  void dispose() {
    _mapController?.dispose();
    _siteNameController.dispose();
    _siteAddressController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
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
            _buildMapCard(),
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
    return _buildCard(
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
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: _siteAddressController,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _searchLocation(),
                  decoration: const InputDecoration(
                    labelText: 'Search Address',
                    prefixIcon: Icon(Icons.location_on_outlined),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: _isSearching ? null : _searchLocation,
                  child: _isSearching
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.search),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildInfoRow('Latitude', _sitePosition.latitude.toStringAsFixed(6)),
          _buildInfoRow(
            'Longitude',
            _sitePosition.longitude.toStringAsFixed(6),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _latitudeController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                  decoration: const InputDecoration(labelText: 'Manual Lat'),
                  onChanged: (_) => _applyManualCoordinates(),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _longitudeController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                  decoration: const InputDecoration(labelText: 'Manual Lon'),
                  onChanged: (_) => _applyManualCoordinates(),
                ),
              ),
            ],
          ),
          if (_currentPosition != null)
            _buildInfoRow(
              'Your Location',
              '${_currentPosition!.latitude.toStringAsFixed(5)}, '
                  '${_currentPosition!.longitude.toStringAsFixed(5)}',
            ),
        ],
      ),
    );
  }

  Widget _buildMapCard() {
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Location Map',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                onPressed: _useCurrentLocation,
                icon: const Icon(Icons.my_location),
                tooltip: 'Use current location',
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 280,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: _sitePosition,
                  zoom: 16,
                ),
                myLocationEnabled: true,
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false,
                markers: {
                  Marker(
                    markerId: const MarkerId('site'),
                    position: _sitePosition,
                    draggable: true,
                    infoWindow: InfoWindow(
                      title: _siteNameController.text.trim().isEmpty
                          ? 'Selected Site'
                          : _siteNameController.text.trim(),
                    ),
                    onDragEnd: _selectPosition,
                  ),
                  if (_currentPosition != null)
                    Marker(
                      markerId: const MarkerId('current'),
                      position: _currentPosition!,
                      icon: BitmapDescriptor.defaultMarkerWithHue(
                        BitmapDescriptor.hueAzure,
                      ),
                      infoWindow: const InfoWindow(title: 'Your Location'),
                    ),
                },
                circles: {
                  Circle(
                    circleId: const CircleId('radius'),
                    center: _sitePosition,
                    radius: _radiusMeters,
                    fillColor: AppTheme.primaryColor.withValues(alpha: 0.12),
                    strokeColor: AppTheme.primaryColor,
                    strokeWidth: 2,
                  ),
                },
                onMapCreated: (controller) {
                  _mapController = controller;
                },
                onTap: _selectPosition,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap the map or drag the marker to select the office geofence center.',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildRadiusCard() {
    return _buildCard(
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
          Text(
            'If a checked-in employee leaves this radius, the app will auto check out.',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard() {
    return _buildCard(
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

              return Wrap(
                spacing: 10,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
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
                  Text(
                    'Distance: ${snapshot.distanceMeters.toStringAsFixed(0)}m',
                    style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                  ),
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
            subtitle: const Text('Monitor location while checked in'),
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
            subtitle: const Text('Notify and auto check out when outside'),
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
            onPressed: () async {
              setState(() {
                _radiusMeters = AppConstants.geofenceDefaultRadius;
                _autoAlerts = true;
                _monitoringEnabled = false;
                _sitePosition = const LatLng(
                  AppConstants.geofenceSiteLat,
                  AppConstants.geofenceSiteLon,
                );
                _siteNameController.text = AppConstants.geofenceSiteName;
                _siteAddressController.text = AppConstants.geofenceSiteAddress;
              });
              await _saveSettings();
              if (!mounted) return;
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
            onPressed: _isSaving
                ? null
                : () async {
                    await _saveSettings();
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Geofence settings saved')),
                    );
                  },
            child: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save Settings'),
          ),
        ),
      ],
    );
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final lat = prefs.getDouble(_prefSiteLat) ?? AppConstants.geofenceSiteLat;
    final lon = prefs.getDouble(_prefSiteLon) ?? AppConstants.geofenceSiteLon;
    await _loadServerSettings(prefs);
    if (!mounted) return;
    setState(() {
      final savedLat = prefs.getDouble(_prefSiteLat) ?? lat;
      final savedLon = prefs.getDouble(_prefSiteLon) ?? lon;
      _sitePosition = LatLng(savedLat, savedLon);
      _syncCoordinateFields();
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

  Future<void> _saveSettings() async {
    setState(() {
      _isSaving = true;
    });
    final prefs = await SharedPreferences.getInstance();
    final siteName = _siteNameController.text.trim().isEmpty
        ? AppConstants.geofenceSiteName
        : _siteNameController.text.trim();
    final siteAddress = _siteAddressController.text.trim().isEmpty
        ? AppConstants.geofenceSiteAddress
        : _siteAddressController.text.trim();
    await prefs.setString('geofence_site_name', siteName);
    await prefs.setString('geofence_site_address', siteAddress);
    await prefs.setDouble(_prefSiteLat, _sitePosition.latitude);
    await prefs.setDouble(_prefSiteLon, _sitePosition.longitude);
    try {
      await _apiClient.postJson('/api/geofence', {
        'siteName': siteName,
        'siteAddress': siteAddress,
        'centerLatitude': _sitePosition.latitude,
        'centerLongitude': _sitePosition.longitude,
        'radiusMeters': _radiusMeters,
      });
    } catch (_) {
      // Local settings still remain available if the server is offline.
    }
    await GeofenceMonitor.instance.updateSettings(
      radiusMeters: _radiusMeters,
      autoAlerts: _autoAlerts,
      enabled: _monitoringEnabled,
      siteLatitude: _sitePosition.latitude,
      siteLongitude: _sitePosition.longitude,
    );
    if (mounted) {
      setState(() {
        _isSaving = false;
      });
    }
  }

  Future<void> _loadServerSettings(SharedPreferences prefs) async {
    try {
      final response = await _apiClient.get('/api/geofence');
      if (response.statusCode != 200 || response.body.isEmpty) {
        return;
      }
      final decoded = Map<String, dynamic>.from(
        const JsonDecoder().convert(response.body) as Map,
      );
      if (decoded['exists'] != true || decoded['data'] is! Map) {
        return;
      }
      final data = Map<String, dynamic>.from(decoded['data'] as Map);
      final siteName = data['siteName']?.toString();
      final siteAddress = data['siteAddress']?.toString();
      final lat = _toDouble(data['centerLatitude']);
      final lon = _toDouble(data['centerLongitude']);
      final radius = _toDouble(data['radiusMeters']);
      if (siteName != null && siteName.isNotEmpty) {
        await prefs.setString('geofence_site_name', siteName);
      }
      if (siteAddress != null && siteAddress.isNotEmpty) {
        await prefs.setString('geofence_site_address', siteAddress);
      }
      if (lat != null && lon != null) {
        await prefs.setDouble(_prefSiteLat, lat);
        await prefs.setDouble(_prefSiteLon, lon);
      }
      if (radius != null) {
        await prefs.setDouble('geofence_radius', radius);
      }
    } catch (_) {
      // Use local settings if server settings cannot be loaded.
    }
  }

  Future<void> _searchLocation() async {
    final query = _siteAddressController.text.trim();
    if (query.isEmpty) {
      return;
    }

    setState(() {
      _isSearching = true;
    });

    try {
      final locations = await geocoding.locationFromAddress(query);
      if (locations.isEmpty) {
        throw Exception('Location not found');
      }
      final location = locations.first;
      _selectPosition(LatLng(location.latitude, location.longitude));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Unable to find location. Try a fuller address or enter lat/lon manually. $error',
          ),
          backgroundColor: AppTheme.warningColor,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
      }
    }
  }

  Future<void> _useCurrentLocation() async {
    final permission = await _ensureLocationPermission();
    if (!permission) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location permission is required.')),
      );
      return;
    }

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
    final latLng = LatLng(position.latitude, position.longitude);
    setState(() {
      _currentPosition = latLng;
    });
    _selectPosition(latLng);
  }

  Future<bool> _ensureLocationPermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    return permission != LocationPermission.denied &&
        permission != LocationPermission.deniedForever;
  }

  void _selectPosition(LatLng position) {
    setState(() {
      _sitePosition = position;
      _syncCoordinateFields();
    });
    _mapController?.animateCamera(CameraUpdate.newLatLngZoom(position, 16));
  }

  void _syncCoordinateFields() {
    _latitudeController.text = _sitePosition.latitude.toStringAsFixed(6);
    _longitudeController.text = _sitePosition.longitude.toStringAsFixed(6);
  }

  void _applyManualCoordinates() {
    final lat = double.tryParse(_latitudeController.text.trim());
    final lon = double.tryParse(_longitudeController.text.trim());
    if (lat == null || lon == null) {
      return;
    }
    if (lat < -90 || lat > 90 || lon < -180 || lon > 180) {
      return;
    }
    final position = LatLng(lat, lon);
    setState(() {
      _sitePosition = position;
    });
    _mapController?.animateCamera(CameraUpdate.newLatLngZoom(position, 16));
  }

  double? _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value?.toString() ?? '');
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

  Widget _buildCard({required Widget child}) {
    return Container(
      width: double.infinity,
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
      child: child,
    );
  }
}
