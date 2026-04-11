import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:gyeol/data/database/database.dart';
import 'package:gyeol/data/models/thread_models.dart';

class ThreadRepository {
  ThreadRepository(this._db);
  final AppDatabase _db;

  Future<void> saveThread(ThreadDefinition thread) {
    return _db.saveThread(
      ThreadsCompanion.insert(
        name: thread.name,
        path: thread.path,
        layerNames: jsonEncode(thread.layerNames),
        contextPrompt: Value(thread.contextPrompt),
        enabled: Value(thread.enabled),
        status: Value(thread.status.name),
      ),
    );
  }

  Future<List<ThreadDefinition>> listThreads() async {
    final rows = await _db.listThreads();
    return rows.map(_threadFromRow).toList();
  }

  Stream<List<ThreadDefinition>> watchThreads() {
    return _db.watchThreads().map((rows) => rows.map(_threadFromRow).toList());
  }

  Future<ThreadDefinition?> getThread(String name) async {
    final row = await _db.getThread(name);
    return row != null ? _threadFromRow(row) : null;
  }

  Future<void> deleteThread(String name) => _db.deleteThread(name);

  ThreadDefinition _threadFromRow(Thread r) {
    return ThreadDefinition(
      name: r.name,
      path: r.path,
      layerNames: _decodeStringList(r.layerNames),
      contextPrompt: r.contextPrompt,
      enabled: r.enabled,
      status: ThreadStatus.values.firstWhere(
        (s) => s.name == r.status,
        orElse: () => ThreadStatus.idle,
      ),
    );
  }

  List<String> _decodeStringList(String json) {
    try {
      final decoded = jsonDecode(json);
      if (decoded is! List) return [];
      return decoded.whereType<String>().toList();
    } on FormatException {
      return [];
    }
  }
}
