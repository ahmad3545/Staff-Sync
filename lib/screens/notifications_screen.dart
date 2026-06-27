import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:fyp/services/api_client.dart';
import 'package:fyp/services/user_context.dart';
import 'package:fyp/utils/app_theme.dart';
import 'package:intl/intl.dart';
import 'package:translator/translator.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _isLoading = false;
  final List<Map<String, dynamic>> _notifications = [];
  final ApiClient _apiClient = ApiClient();
  final UserContext _userContext = UserContext();
  final FlutterTts _flutterTts = FlutterTts();
  final GoogleTranslator _translator = GoogleTranslator();

  static const Map<String, String> _languages = {
    'en': 'English',
    'ur': 'Urdu',
    'hi': 'Hindi',
    'ar': 'Arabic',
    'fr': 'French',
    'es': 'Spanish',
    'de': 'German',
    'it': 'Italian',
    'pt': 'Portuguese',
    'tr': 'Turkish',
    'ru': 'Russian',
    'zh-cn': 'Chinese (Simplified)',
    'zh-tw': 'Chinese (Traditional)',
    'ja': 'Japanese',
    'ko': 'Korean',
    'bn': 'Bengali',
    'fa': 'Persian',
    'ms': 'Malay',
    'th': 'Thai',
    'id': 'Indonesian',
    'nl': 'Dutch',
    'pl': 'Polish',
  };

  @override
  void initState() {
    super.initState();
    _flutterTts.setSpeechRate(0.45);
    _flutterTts.setPitch(1.0);
    _loadNotifications();
  }

  @override
  void dispose() {
    _flutterTts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _notifications.clear();
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('All notifications cleared')),
              );
            },
            child: const Text('Clear', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
          ? _buildEmptyState()
          : _buildList(),
    );
  }

  Widget _buildList() {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _notifications.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final item = _notifications[index];
        final color = _typeColor(item['type']?.toString() ?? 'info');
        return Container(
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: color.withOpacity(0.15),
                child: Icon(
                  _typeIcon(item['type']?.toString()),
                  color: color,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['title']?.toString() ?? '-',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item['translatedMessage']?.toString().isNotEmpty == true
                          ? item['translatedMessage'].toString()
                          : item['message']?.toString() ?? '-',
                      style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        TextButton.icon(
                          onPressed: () => _translateNotification(index),
                          icon: const Icon(Icons.translate, size: 18),
                          label: const Text('Translate'),
                        ),
                        const SizedBox(width: 8),
                        TextButton.icon(
                          onPressed: () => _speakNotification(item),
                          icon: const Icon(Icons.volume_up, size: 18),
                          label: const Text('Voice'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item['time']?.toString() ?? '-',
                      style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_off, size: 60, color: Colors.grey[400]),
          const SizedBox(height: 12),
          const Text(
            'No notifications yet',
            style: TextStyle(fontSize: 14, color: Colors.black54),
          ),
        ],
      ),
    );
  }

  Color _typeColor(String type) {
    switch (type) {
      case 'success':
        return AppTheme.successColor;
      case 'warning':
        return AppTheme.warningColor;
      default:
        return AppTheme.primaryColor;
    }
  }

  IconData _typeIcon(String? type) {
    switch (type) {
      case 'success':
        return Icons.check_circle;
      case 'warning':
        return Icons.warning;
      default:
        return Icons.notifications;
    }
  }

  Future<void> _loadNotifications() async {
    final userId = _userContext.userId;
    if (userId == null || userId.isEmpty) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await _apiClient.get('/api/notifications/$userId');
      if (response.statusCode == 200) {
        final list = List<Map<String, dynamic>>.from(
          jsonDecode(response.body) as List<dynamic>,
        );
        final mapped = list.map((item) {
          final data = item['data'] as Map<String, dynamic>? ?? {};
          final createdAt = _parseDate(data['createdAtUtc']);
          return {
            'title': data['title'] ?? '-',
            'message': data['body'] ?? '-',
            'translatedMessage': '',
            'time': createdAt == null
                ? '-'
                : DateFormat('MMM dd, hh:mm a').format(createdAt),
            'type': data['type'] ?? 'info',
            'language': 'en',
          };
        }).toList();

        setState(() {
          _notifications
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

  DateTime? _parseDate(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is String) {
      return DateTime.tryParse(value)?.toLocal();
    }
    return null;
  }

  Future<void> _translateNotification(int index) async {
    final item = _notifications[index];
    final selectedLanguage = await _chooseLanguage();
    if (selectedLanguage == null) {
      return;
    }

    final sourceText = item['translatedMessage']?.toString().isNotEmpty == true
        ? item['translatedMessage'].toString()
        : item['message']?.toString() ?? '';

    if (sourceText.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No message to translate')));
      return;
    }

    try {
      final translated = await _translator.translate(
        sourceText,
        to: selectedLanguage,
      );
      final translatedText = translated.text.trim();

      if (translatedText.isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Translation failed')));
        return;
      }

      setState(() {
        _notifications[index]['translatedMessage'] = translatedText;
        _notifications[index]['language'] = selectedLanguage;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Translated to ${_languages[selectedLanguage]}'),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Translation error: $e')));
    }
  }

  Future<void> _speakNotification(Map<String, dynamic> item) async {
    final text = item['translatedMessage']?.toString().isNotEmpty == true
        ? item['translatedMessage'].toString()
        : item['message']?.toString() ?? '';
    final languageCode = _ttsLanguageCode(item['language']?.toString());

    if (text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No message to speak')));
      return;
    }

    try {
      await _flutterTts.stop();
      await _flutterTts.setLanguage(languageCode);
      await _flutterTts.speak(text);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Voice announcement started')),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Voice error: $e')));
    }
  }

  Future<String?> _chooseLanguage() async {
    return showDialog<String>(
      context: context,
      builder: (dialogContext) {
        String selected = 'ur';
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Translate notification'),
              content: DropdownButtonFormField<String>(
                initialValue: selected,
                items: _languages.entries
                    .map(
                      (entry) => DropdownMenuItem(
                        value: entry.key,
                        child: Text(entry.value),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setDialogState(() {
                    selected = value;
                  });
                },
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(dialogContext, selected),
                  child: const Text('Translate'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _ttsLanguageCode(String? language) {
    switch (language) {
      case 'ur':
        return 'ur-PK';
      case 'hi':
        return 'hi-IN';
      case 'ar':
        return 'ar-SA';
      case 'fr':
        return 'fr-FR';
      case 'es':
        return 'es-ES';
      case 'de':
        return 'de-DE';
      case 'it':
        return 'it-IT';
      case 'pt':
        return 'pt-PT';
      case 'tr':
        return 'tr-TR';
      case 'ru':
        return 'ru-RU';
      case 'zh-cn':
        return 'zh-CN';
      case 'zh-tw':
        return 'zh-TW';
      case 'ja':
        return 'ja-JP';
      case 'ko':
        return 'ko-KR';
      case 'bn':
        return 'bn-BD';
      case 'fa':
        return 'fa-IR';
      case 'ms':
        return 'ms-MY';
      case 'th':
        return 'th-TH';
      case 'id':
        return 'id-ID';
      case 'nl':
        return 'nl-NL';
      case 'pl':
        return 'pl-PL';
      default:
        return 'en-US';
    }
  }
}
