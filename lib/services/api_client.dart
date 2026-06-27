import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:fyp/constants/app_constants.dart';
import 'package:fyp/services/auth_service.dart';

class ApiClient {
  ApiClient({AuthService? authService})
    : _authService = authService ?? AuthService();

  final AuthService _authService;
  static const Duration _timeout = Duration(seconds: 10);

  Uri _buildUri(String path, [Map<String, String>? query]) {
    final normalized = path.startsWith('/') ? path : '/$path';
    return Uri.parse(
      AppConstants.apiBaseUrl + normalized,
    ).replace(queryParameters: query);
  }

  Future<Map<String, String>> _headers({bool json = true}) async {
    final headers = <String, String>{};
    if (json) {
      headers['Content-Type'] = 'application/json';
    }

    final token = await _authService.getIdToken();
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    return headers;
  }

  Future<http.Response> get(String path, {Map<String, String>? query}) async {
    final uri = _buildUri(path, query);
    debugPrint('ApiClient GET $uri');
    final response = await http
        .get(uri, headers: await _headers())
        .timeout(_timeout);
    debugPrint('ApiClient GET ${response.statusCode} ${response.body}');
    return response;
  }

  Future<http.Response> postJson(String path, Map<String, dynamic> body) async {
    final uri = _buildUri(path);
    debugPrint('ApiClient POST $uri');
    debugPrint('ApiClient POST body: ${jsonEncode(body)}');
    final response = await http
        .post(uri, headers: await _headers(), body: jsonEncode(body))
        .timeout(_timeout);
    debugPrint('ApiClient POST ${response.statusCode} ${response.body}');
    return response;
  }

  Future<http.Response> putJson(String path, Map<String, dynamic> body) async {
    final uri = _buildUri(path);
    return http
        .put(uri, headers: await _headers(), body: jsonEncode(body))
        .timeout(_timeout);
  }

  Future<http.Response> delete(String path) async {
    final uri = _buildUri(path);
    return http
        .delete(uri, headers: await _headers(json: false))
        .timeout(_timeout);
  }

  Future<http.StreamedResponse> postMultipart(
    String path, {
    required Map<String, String> fields,
    required http.MultipartFile file,
  }) async {
    final uri = _buildUri(path);
    final request = http.MultipartRequest('POST', uri);
    request.fields.addAll(fields);

    final token = await _authService.getIdToken();
    if (token != null && token.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $token';
    }

    request.files.add(file);
    return request.send().timeout(_timeout);
  }
}
