import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:fyp/services/api_client.dart';
import 'package:fyp/utils/app_theme.dart';

class AbsentPredictionScreen extends StatefulWidget {
  const AbsentPredictionScreen({super.key});

  @override
  State<AbsentPredictionScreen> createState() => _AbsentPredictionScreenState();
}

class _AbsentPredictionScreenState extends State<AbsentPredictionScreen> {
  final ApiClient _apiClient = ApiClient();
  final List<Map<String, dynamic>> _predictions = [];
  bool _isLoading = false;
  String? _error;
  String _generatedAt = '-';

  @override
  void initState() {
    super.initState();
    _loadPredictions();
  }

  @override
  Widget build(BuildContext context) {
    final highRisk = _predictions
        .where((item) => item['riskLevel']?.toString() == 'high')
        .length;
    final mediumRisk = _predictions
        .where((item) => item['riskLevel']?.toString() == 'medium')
        .length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Absent Prediction'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _loadPredictions,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadPredictions,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeaderCard(highRisk: highRisk, mediumRisk: mediumRisk),
              const SizedBox(height: 16),
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_error != null)
                _buildMessageCard(_error!)
              else if (_predictions.isEmpty)
                _buildMessageCard('No staff data found for prediction.')
              else
                ..._predictions.map(_buildPredictionCard),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderCard({required int highRisk, required int mediumRisk}) {
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.psychology_alt_outlined,
                  color: AppTheme.primaryColor,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'AI Absentee Forecast',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildMiniStat(
                  'High Risk',
                  '$highRisk',
                  AppTheme.errorColor,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildMiniStat(
                  'Medium Risk',
                  '$mediumRisk',
                  AppTheme.warningColor,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildMiniStat(
                  'Staff',
                  '${_predictions.length}',
                  AppTheme.primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Updated: $_generatedAt',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildPredictionCard(Map<String, dynamic> prediction) {
    final riskLevel = prediction['riskLevel']?.toString() ?? 'low';
    final riskColor = _riskColor(riskLevel);
    final likelyAbsentDays = _listOfMaps(prediction['likelyAbsentDays']);
    final leaveFriendlyDays = _listOfMaps(prediction['leaveFriendlyDays']);
    final workload = _listOfMaps(prediction['dailyWorkload']);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      prediction['name']?.toString() ?? '-',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      prediction['department']?.toString() ?? '-',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              _buildRiskBadge(riskLevel, riskColor),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            prediction['summary']?.toString() ?? '-',
            style: const TextStyle(fontSize: 12, color: Colors.black87),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildMetric(
                  'Risk',
                  '${_numText(prediction['riskScore'])}%',
                  riskColor,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetric(
                  'Attendance',
                  '${_numText(prediction['attendanceRate'])}%',
                  AppTheme.successColor,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetric(
                  'Open Tasks',
                  _numText(prediction['openTasks']),
                  AppTheme.primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildSection(
            'Likely Absent Days',
            likelyAbsentDays.isEmpty
                ? ['No strong absence pattern found.']
                : likelyAbsentDays
                      .map(
                        (day) =>
                            '${day['label'] ?? '-'} • ${_numText(day['probability'])}% • ${day['reason'] ?? '-'}',
                      )
                      .toList(),
          ),
          _buildSection(
            'Best Leave Windows',
            leaveFriendlyDays.isEmpty
                ? ['No low-workload day found in next 7 days.']
                : leaveFriendlyDays
                      .map((day) => '${day['label'] ?? '-'} • ${day['reason']}')
                      .toList(),
          ),
          _buildWorkloadChips(workload),
        ],
      ),
    );
  }

  Widget _buildRiskBadge(String riskLevel, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '${riskLevel.toUpperCase()} RISK',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Widget _buildMetric(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 3),
          Text(label, style: const TextStyle(fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<String> lines) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 5),
          ...lines.map(
            (line) => Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Text(
                line,
                style: TextStyle(fontSize: 12, color: Colors.grey[700]),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkloadChips(List<Map<String, dynamic>> workload) {
    if (workload.isEmpty) {
      return const SizedBox.shrink();
    }

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: workload.map((day) {
        final level = day['level']?.toString() ?? 'low';
        final color = _workloadColor(level);
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.09),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: 0.25)),
          ),
          child: Text(
            '${day['label'] ?? '-'}: ${level.toUpperCase()}',
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildMessageCard(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(message, style: const TextStyle(color: Colors.black54)),
    );
  }

  Future<void> _loadPredictions() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await _apiClient.get('/api/ml/absentee-predictions');
      if (response.statusCode != 200) {
        throw Exception('Failed to load predictions (${response.statusCode})');
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final predictions = List<Map<String, dynamic>>.from(
        (decoded['predictions'] as List<dynamic>? ?? []).map(
          (item) => Map<String, dynamic>.from(item as Map),
        ),
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _predictions
          ..clear()
          ..addAll(predictions);
        _generatedAt = _formatGeneratedAt(decoded['generatedAtUtc']);
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  List<Map<String, dynamic>> _listOfMaps(dynamic value) {
    if (value is! List) {
      return [];
    }
    return value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  String _numText(dynamic value) {
    if (value is num) {
      return value.round().toString();
    }
    return value?.toString() ?? '0';
  }

  String _formatGeneratedAt(dynamic value) {
    final parsed = DateTime.tryParse(value?.toString() ?? '')?.toLocal();
    if (parsed == null) {
      return '-';
    }
    final hour = parsed.hour % 12 == 0 ? 12 : parsed.hour % 12;
    final minute = parsed.minute.toString().padLeft(2, '0');
    final suffix = parsed.hour >= 12 ? 'PM' : 'AM';
    return '${parsed.day}/${parsed.month}/${parsed.year} $hour:$minute $suffix';
  }

  Color _riskColor(String riskLevel) {
    switch (riskLevel) {
      case 'high':
        return AppTheme.errorColor;
      case 'medium':
        return AppTheme.warningColor;
      default:
        return AppTheme.successColor;
    }
  }

  Color _workloadColor(String level) {
    switch (level) {
      case 'high':
        return AppTheme.errorColor;
      case 'medium':
        return AppTheme.warningColor;
      default:
        return AppTheme.successColor;
    }
  }
}
