import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

class ApiClient {
  ApiClient({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _db = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  Future<http.Response> get(String path, {Map<String, String>? query}) async {
    try {
      final result = await _handleGet(_normalizePath(path), query ?? {});
      return _json(result);
    } catch (error) {
      return _error(error);
    }
  }

  Future<http.Response> postJson(String path, Map<String, dynamic> body) async {
    try {
      final result = await _handlePost(_normalizePath(path), body);
      return _json(result);
    } catch (error) {
      return _error(error);
    }
  }

  Future<http.Response> putJson(String path, Map<String, dynamic> body) async {
    try {
      final result = await _handlePut(_normalizePath(path), body);
      return _json(result);
    } catch (error) {
      return _error(error);
    }
  }

  Future<http.Response> delete(String path) async {
    try {
      final result = await _handleDelete(_normalizePath(path));
      return _json(result);
    } catch (error) {
      return _error(error);
    }
  }

  Future<http.StreamedResponse> postMultipart(
    String path, {
    required Map<String, String> fields,
    required http.MultipartFile file,
  }) async {
    final response = http.Response('Multipart upload is not available.', 501);
    return http.StreamedResponse(
      Stream.value(response.bodyBytes),
      response.statusCode,
      headers: response.headers,
    );
  }

  Future<dynamic> _handleGet(String path, Map<String, String> query) async {
    if (path == '/api/users') {
      return _list('users', orderBy: 'createdAtUtc');
    }
    if (path.startsWith('/api/users/')) {
      return _doc('users', path.split('/').last);
    }
    if (path == '/api/attendance/recent') {
      final limit = int.tryParse(query['limit'] ?? '') ?? 20;
      return _list('attendance', orderBy: 'timestampUtc', limit: limit);
    }
    if (path == '/api/attendance/summary') {
      return _attendanceSummary();
    }
    if (path.startsWith('/api/attendance/')) {
      return _listWhere(
        'attendance',
        'userId',
        path.split('/').last,
        orderBy: 'timestampUtc',
      );
    }
    if (path == '/api/leave') {
      return _list('leaveRequests', orderBy: 'createdAtUtc');
    }
    if (path.startsWith('/api/leave/')) {
      return _listWhere(
        'leaveRequests',
        'userId',
        path.split('/').last,
        orderBy: 'createdAtUtc',
      );
    }
    if (path == '/api/tasks') {
      return _list('tasks', orderBy: 'createdAtUtc');
    }
    if (path.startsWith('/api/tasks/')) {
      return _listWhere(
        'tasks',
        'userId',
        path.split('/').last,
        orderBy: 'createdAtUtc',
      );
    }
    if (path == '/api/shifts') {
      return _list('shifts', orderBy: 'createdAtUtc');
    }
    if (path.startsWith('/api/notifications/')) {
      return _listWhere(
        'notifications',
        'userId',
        path.split('/').last,
        orderBy: 'createdAtUtc',
      );
    }
    if (path == '/api/departments') {
      return _list('departments', orderBy: 'createdAtUtc');
    }
    if (path == '/api/reports') {
      return _list('reports', orderBy: 'createdAtUtc');
    }
    if (path == '/api/geofence') {
      final snapshot = await _db.collection('geofence').doc('default').get();
      return {'exists': snapshot.exists, 'data': snapshot.data() ?? {}};
    }
    if (path.startsWith('/api/payroll/payslip/')) {
      return _doc('payroll', path.split('/').last);
    }
    if (path.startsWith('/api/payroll/')) {
      return _listWhere(
        'payroll',
        'userId',
        path.split('/').last,
        orderBy: 'createdAtUtc',
      );
    }
    if (path == '/api/ml/absentee-predictions') {
      return _absenteePredictions();
    }
    if (path.startsWith('/api/exports/')) {
      return _exportCsv(path.split('/').last, query);
    }
    throw UnsupportedError('Unsupported Firebase GET: $path');
  }

  Future<dynamic> _handlePost(String path, Map<String, dynamic> body) async {
    switch (path) {
      case '/api/attendance/mark':
        return _add('attendance', body);
      case '/api/attendance/mark-batch':
        final records = (body['records'] as List<dynamic>? ?? []);
        for (final record in records) {
          await _db
              .collection('attendance')
              .add(_withServerDate(record as Map));
        }
        return {'created': records.length};
      case '/api/users/profile':
        final userId = body['userId']?.toString() ?? _auth.currentUser?.uid;
        if (userId == null || userId.isEmpty) {
          throw ArgumentError('userId required');
        }
        await _db
            .collection('users')
            .doc(userId)
            .set(_clean(body)..remove('userId'), SetOptions(merge: true));
        return {'updated': true};
      case '/api/admin/users':
        return _createStaffProfile(body);
      case '/api/leave/request':
        return _add('leaveRequests', {...body, 'status': 'pending'});
      case '/api/leave/approve':
        await _db.collection('leaveRequests').doc(body['leaveId']).set({
          'status': body['status'],
          'approverId': body['approverId'],
          'notes': body['notes'],
          'updatedAtUtc': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        return {'updated': true};
      case '/api/tasks/assign':
        return _assignTask(body);
      case '/api/tasks/verify':
        await _db.collection('tasks').doc(body['taskId']).set({
          'status': body['status'],
          'reviewerId': body['reviewerId'],
          'notes': body['notes'],
          'updatedAtUtc': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        return {'updated': true};
      case '/api/notifications/broadcast':
        return _broadcast(body);
      case '/api/departments':
        return _add('departments', body);
      case '/api/reports/generate':
        return _add('reports', {...body, 'status': 'generated'});
      case '/api/geofence':
        await _db.collection('geofence').doc('default').set({
          ..._clean(body),
          'updatedAtUtc': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        return {'updated': true};
      case '/api/payroll/calculate':
        return _calculatePayroll(body);
      case '/api/admin/payroll-settings':
        await _db
            .collection('settings')
            .doc('payroll')
            .set(_clean(body), SetOptions(merge: true));
        return {'updated': true};
      case '/api/shifts':
        return _add('shifts', body);
      case '/api/shifts/assign':
        return _add('shiftAssignments', body);
      default:
        throw UnsupportedError('Unsupported Firebase POST: $path');
    }
  }

  Future<dynamic> _handlePut(String path, Map<String, dynamic> body) async {
    if (path == '/api/shifts') {
      final id = body['id']?.toString() ?? body['shiftId']?.toString();
      if (id == null || id.isEmpty) {
        throw ArgumentError('shift id required');
      }
      await _db
          .collection('shifts')
          .doc(id)
          .set(
            {..._clean(body), 'updatedAtUtc': FieldValue.serverTimestamp()}
              ..remove('id')
              ..remove('shiftId'),
            SetOptions(merge: true),
          );
      return {'updated': true};
    }
    throw UnsupportedError('Unsupported Firebase PUT: $path');
  }

  Future<dynamic> _handleDelete(String path) async {
    if (path.startsWith('/api/users/')) {
      await _db.collection('users').doc(path.split('/').last).delete();
      return {'deleted': true};
    }
    if (path.startsWith('/api/shifts/')) {
      await _db.collection('shifts').doc(path.split('/').last).delete();
      return {'deleted': true};
    }
    throw UnsupportedError('Unsupported Firebase DELETE: $path');
  }

  Future<List<Map<String, dynamic>>> _list(
    String collection, {
    String? orderBy,
    int limit = 200,
  }) async {
    final snapshot = await _db.collection(collection).limit(limit).get();
    final rows = snapshot.docs.map(_document).toList();
    _sortRows(rows, orderBy);
    return rows;
  }

  Future<List<Map<String, dynamic>>> _listWhere(
    String collection,
    String field,
    String value, {
    String? orderBy,
    int limit = 200,
  }) async {
    final snapshot = await _db
        .collection(collection)
        .where(field, isEqualTo: value)
        .limit(limit)
        .get();
    final rows = snapshot.docs.map(_document).toList();
    _sortRows(rows, orderBy);
    return rows;
  }

  Future<Map<String, dynamic>> _doc(String collection, String id) async {
    final snapshot = await _db.collection(collection).doc(id).get();
    return {'id': snapshot.id, 'data': snapshot.data() ?? {}};
  }

  Future<Map<String, dynamic>> _add(
    String collection,
    Map<String, dynamic> body,
  ) async {
    final doc = await _db.collection(collection).add(_withServerDate(body));
    return {'id': doc.id, 'status': 'generated', 'created': true};
  }

  Future<Map<String, dynamic>> _assignTask(Map<String, dynamic> body) async {
    final doc = await _db.collection('tasks').add({
      ..._clean(body),
      'status': 'assigned',
      'createdAtUtc': FieldValue.serverTimestamp(),
    });
    final userId = body['userId']?.toString();
    if (userId != null && userId.isNotEmpty) {
      await _db.collection('users').doc(userId).set({
        'assignedTasks': FieldValue.arrayUnion([doc.id]),
        'updatedAtUtc': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
    return {'id': doc.id};
  }

  Future<Map<String, dynamic>> _createStaffProfile(
    Map<String, dynamic> body,
  ) async {
    final id = body['email']?.toString().trim();
    if (id == null || id.isEmpty) {
      throw ArgumentError('email required');
    }
    await _db.collection('users').doc(id).set({
      'email': id,
      'fullName': body['fullName'],
      'phone': body['phone'],
      'departmentId': body['departmentId'],
      'role': body['role'] ?? 'employee',
      'createdAtUtc': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    return {'id': id};
  }

  Future<Map<String, dynamic>> _broadcast(Map<String, dynamic> body) async {
    final users = await _db.collection('users').limit(500).get();
    for (final user in users.docs) {
      await _db.collection('notifications').add({
        'userId': user.id,
        'title': body['title'],
        'body': body['body'],
        'type': body['type'] ?? 'info',
        'createdAtUtc': FieldValue.serverTimestamp(),
      });
    }
    return {'sent': users.docs.length};
  }

  Future<Map<String, dynamic>> _attendanceSummary() async {
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day);
    final attendance = await _list('attendance', limit: 500);
    final presentUsers = <String>{};
    for (final row in attendance) {
      final data = row['data'] as Map<String, dynamic>;
      final time = _parseDate(data['timestampUtc']);
      final status = data['status']?.toString();
      if (time != null &&
          !time.isBefore(start) &&
          (status == 'present' || status == 'check_in')) {
        final userId = data['userId']?.toString();
        if (userId != null) presentUsers.add(userId);
      }
    }
    return {
      'presentToday': presentUsers.length,
      'totalRecords': attendance.length,
    };
  }

  Future<Map<String, dynamic>> _calculatePayroll(
    Map<String, dynamic> body,
  ) async {
    final base = _toDouble(body['baseSalary']);
    final allowances = _toDouble(body['allowances']);
    final deductions = _toDouble(body['deductions']);
    final overtimeHours = _toDouble(body['overtimeHours']);
    final overtimeRate = 2000.0;
    final net = base + allowances + overtimeHours * overtimeRate - deductions;
    final data = {
      ..._clean(body),
      'overtimeRate': overtimeRate,
      'netSalary': net,
      'status': 'processed',
      'createdAtUtc': FieldValue.serverTimestamp(),
    };
    final doc = await _db.collection('payroll').add(data);
    return {'id': doc.id, 'netSalary': net};
  }

  Future<Map<String, dynamic>> _absenteePredictions() async {
    final users = await _list('users');
    final attendance = await _list('attendance', limit: 500);
    final tasks = await _list('tasks', limit: 500);
    final predictions = users.map((user) {
      final userId = user['id']?.toString() ?? '';
      final userData = user['data'] as Map<String, dynamic>;
      final userAttendance = attendance.where((row) {
        final data = row['data'] as Map<String, dynamic>;
        return data['userId']?.toString() == userId;
      }).toList();
      final userTasks = tasks.where((row) {
        final data = row['data'] as Map<String, dynamic>;
        return data['userId']?.toString() == userId;
      }).toList();
      final openTasks = userTasks.where((row) {
        final status = ((row['data'] as Map)['status'] ?? '').toString();
        return status != 'completed' && status != 'verified';
      }).length;
      final attendanceRate = userAttendance.isEmpty
          ? 100
          : (userAttendance.length.clamp(0, 22) / 22 * 100).round();
      final risk = (100 - attendanceRate + openTasks * 5).clamp(0, 100);
      final riskLevel = risk >= 70
          ? 'high'
          : risk >= 40
          ? 'medium'
          : 'low';
      return {
        'userId': userId,
        'name': userData['fullName'] ?? userId,
        'department': userData['departmentId'] ?? '-',
        'riskLevel': riskLevel,
        'riskScore': risk,
        'attendanceRate': attendanceRate,
        'presentDays': userAttendance.length,
        'absentDays': (22 - userAttendance.length).clamp(0, 22),
        'openTasks': openTasks,
        'overdueTasks': 0,
        'highPriorityTasks': 0,
        'workloadPressure': openTasks >= 5
            ? 'high'
            : openTasks == 0
            ? 'low'
            : 'medium',
        'likelyAbsentDays': [],
        'leaveFriendlyDays': [],
        'dailyWorkload': [],
        'summary': 'Firebase-based prediction from attendance and open tasks.',
      };
    }).toList();
    return {
      'generatedAtUtc': DateTime.now().toUtc().toIso8601String(),
      'predictions': predictions,
    };
  }

  Future<http.Response> _exportCsv(
    String type,
    Map<String, String> query,
  ) async {
    final collection = switch (type) {
      'attendance' => 'attendance',
      'leaves' => 'leaveRequests',
      'tasks' => 'tasks',
      'payroll' => 'payroll',
      _ => type,
    };
    final rows = await _list(collection, limit: 500);
    final csv = _toCsv(rows);
    return http.Response.bytes(
      utf8.encode(csv),
      200,
      headers: {'content-type': 'text/csv'},
    );
  }

  Map<String, dynamic> _document(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return {'id': doc.id, 'data': _normalizeValue(doc.data())};
  }

  Map<String, dynamic> _withServerDate(Map<dynamic, dynamic> body) {
    final data = _clean(body);
    data.putIfAbsent('createdAtUtc', () => FieldValue.serverTimestamp());
    return data;
  }

  Map<String, dynamic> _clean(Map<dynamic, dynamic> body) {
    final data = <String, dynamic>{};
    body.forEach((key, value) {
      if (value != null) data[key.toString()] = value;
    });
    return data;
  }

  dynamic _normalizeValue(dynamic value) {
    if (value is Timestamp) return value.toDate().toUtc().toIso8601String();
    if (value is DateTime) return value.toUtc().toIso8601String();
    if (value is Map) {
      return value.map(
        (key, child) => MapEntry(key.toString(), _normalizeValue(child)),
      );
    }
    if (value is List) return value.map(_normalizeValue).toList();
    return value;
  }

  DateTime? _parseDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.tryParse(value?.toString() ?? '');
  }

  void _sortRows(List<Map<String, dynamic>> rows, String? field) {
    if (field == null) return;
    rows.sort((a, b) {
      final aData = a['data'] as Map<String, dynamic>;
      final bData = b['data'] as Map<String, dynamic>;
      final aDate = _parseDate(aData[field]);
      final bDate = _parseDate(bData[field]);
      if (aDate == null && bDate == null) return 0;
      if (aDate == null) return 1;
      if (bDate == null) return -1;
      return bDate.compareTo(aDate);
    });
  }

  String _toCsv(List<Map<String, dynamic>> rows) {
    final flatRows = rows.map((row) {
      final data = Map<String, dynamic>.from(row['data'] as Map);
      data['id'] = row['id'];
      return data.map((key, value) => MapEntry(key, value?.toString() ?? ''));
    }).toList();
    if (flatRows.isEmpty) return '';
    final headers = flatRows.expand((row) => row.keys).toSet().toList();
    final lines = [
      headers.map(_escapeCsv).join(','),
      ...flatRows.map(
        (row) => headers.map((h) => _escapeCsv(row[h] ?? '')).join(','),
      ),
    ];
    return lines.join('\n');
  }

  String _escapeCsv(String value) {
    final escaped = value.replaceAll('"', '""');
    return escaped.contains(',') || escaped.contains('\n')
        ? '"$escaped"'
        : escaped;
  }

  double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _normalizePath(String path) => path.startsWith('/') ? path : '/$path';

  http.Response _json(dynamic body, [int status = 200]) {
    if (body is http.Response) return body;
    return http.Response(
      jsonEncode(_normalizeValue(body)),
      status,
      headers: {'content-type': 'application/json'},
    );
  }

  http.Response _error(Object error) {
    return http.Response(error.toString(), 500);
  }
}
