import 'dart:convert';
import 'package:fyp/services/api_client.dart';
import 'package:fyp/services/sync_queue_service.dart';

class SyncManager {
  SyncManager({ApiClient? apiClient, SyncQueueService? queueService})
    : _apiClient = apiClient ?? ApiClient(),
      _queueService = queueService ?? SyncQueueService();

  final ApiClient _apiClient;
  final SyncQueueService _queueService;

  Future<int> syncAll() async {
    final items = await _queueService.fetchAll();
    var successCount = 0;

    for (final item in items) {
      final id = item['id'] as int;
      final method = item['method'] as String;
      final path = item['path'] as String;
      final bodyRaw = item['body'] as String?;
      final body = bodyRaw == null
          ? null
          : jsonDecode(bodyRaw) as Map<String, dynamic>;

      try {
        switch (method.toUpperCase()) {
          case 'POST':
            await _apiClient.postJson(path, body ?? {});
            break;
          case 'PUT':
            await _apiClient.putJson(path, body ?? {});
            break;
          case 'DELETE':
            await _apiClient.delete(path);
            break;
          default:
            break;
        }

        await _queueService.delete(id);
        successCount += 1;
      } catch (_) {
        // Keep item in queue for next sync attempt.
      }
    }

    return successCount;
  }
}
