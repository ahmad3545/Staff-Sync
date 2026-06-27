import 'dart:convert';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class SyncQueueService {
  static const _dbName = 'staffsync_sync.db';
  static const _table = 'sync_queue';

  Database? _db;

  Future<void> init() async {
    if (_db != null) {
      return;
    }

    final dir = await getApplicationDocumentsDirectory();
    final dbPath = p.join(dir.path, _dbName);

    _db = await openDatabase(
      dbPath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $_table (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            method TEXT NOT NULL,
            path TEXT NOT NULL,
            body TEXT,
            createdAt INTEGER NOT NULL
          )
        ''');
      },
    );
  }

  Future<int> enqueue({
    required String method,
    required String path,
    Map<String, dynamic>? body,
  }) async {
    await init();
    return _db!.insert(_table, {
      'method': method,
      'path': path,
      'body': body == null ? null : jsonEncode(body),
      'createdAt': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<List<Map<String, dynamic>>> fetchAll() async {
    await init();
    return _db!.query(_table, orderBy: 'createdAt ASC');
  }

  Future<void> delete(int id) async {
    await init();
    await _db!.delete(_table, where: 'id = ?', whereArgs: [id]);
  }
}
