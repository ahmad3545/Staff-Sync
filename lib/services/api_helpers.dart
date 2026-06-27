import 'dart:convert';
import 'package:http/http.dart' as http;

Map<String, dynamic> parseJson(http.Response response) {
  if (response.body.isEmpty) {
    return {};
  }
  return jsonDecode(response.body) as Map<String, dynamic>;
}

List<Map<String, dynamic>> parseJsonList(http.Response response) {
  if (response.body.isEmpty) {
    return [];
  }
  final parsed = jsonDecode(response.body) as List<dynamic>;
  return parsed.map((e) => e as Map<String, dynamic>).toList();
}
