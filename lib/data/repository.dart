import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../domain/models.dart';
import '../platform/runtime_platform.dart';

const _harmonyStorage = MethodChannel('dev.kejian/storage');

abstract class ScheduleRepository {
  Future<ScheduleData?> load();
  Future<void> save(ScheduleData data);
}

/// Android/iOS use a SQLite transaction; HarmonyOS atomically writes a private
/// JSON file. The preview uses browser storage behind the same interface.
class LocalScheduleRepository implements ScheduleRepository {
  Database? _db;
  Future<Database> get database async => _db ??= await openDatabase(
    '${await getDatabasesPath()}/kejian.db',
    version: 1,
    onCreate: (db, version) async {
      await db.execute(
        'CREATE TABLE documents (id INTEGER PRIMARY KEY, payload TEXT NOT NULL)',
      );
    },
  );
  @override
  Future<ScheduleData?> load() async {
    String? source;
    if (kIsWeb) {
      source = await SharedPreferencesAsync().getString('kejian.document.v1');
    } else if (isHarmonyOS) {
      source = await _harmonyStorage.invokeMethod<String>('load');
    } else {
      final rows = await (await database).query(
        'documents',
        where: 'id = ?',
        whereArgs: [1],
      );
      if (rows.isNotEmpty) source = rows.first['payload'] as String;
    }
    return source == null ? null : ScheduleData.decode(source);
  }

  @override
  Future<void> save(ScheduleData data) async {
    data.validate();
    final source = data.encode();
    if (kIsWeb) {
      await SharedPreferencesAsync().setString('kejian.document.v1', source);
    } else if (isHarmonyOS) {
      await _harmonyStorage.invokeMethod<void>('save', source);
    } else {
      await (await database).transaction((txn) async {
        await txn.insert('documents', {
          'id': 1,
          'payload': source,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      });
    }
  }
}

class MemoryRepository implements ScheduleRepository {
  ScheduleData? value;
  MemoryRepository([this.value]);
  @override
  Future<ScheduleData?> load() async => value;
  @override
  Future<void> save(ScheduleData data) async {
    data.validate();
    value = data;
  }
}
