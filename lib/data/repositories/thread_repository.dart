import 'package:drift/drift.dart';
import 'package:gyeol/data/database/database.dart';
import 'package:gyeol/data/models/thread_models.dart';

class ThreadRepository {
  ThreadRepository(this._db);
  final AppDatabase _db;

  Future<void> saveThread(ThreadDefinition thread) async {
    final existing = await _db.getThread(thread.name);
    final ThreadsCompanion companion;
    if (existing != null) {
      companion = ThreadsCompanion(
        id: Value(existing.id),
        name: Value(thread.name),
        path: Value(thread.path),
        contextPrompt: Value(thread.contextPrompt),
        enabled: Value(thread.enabled),
        status: Value(thread.status.name),
      );
    } else {
      companion = ThreadsCompanion.insert(
        name: thread.name,
        path: thread.path,
        contextPrompt: Value(thread.contextPrompt),
        enabled: Value(thread.enabled),
        status: Value(thread.status.name),
      );
    }
    await _db.saveThread(companion);
  }

  Future<List<ThreadDefinition>> listThreads() async {
    final rows = await _db.listThreads();
    return rows.map(_fromRow).toList();
  }

  Stream<List<ThreadDefinition>> watchThreads() {
    return _db.watchThreads().map((rows) => rows.map(_fromRow).toList());
  }

  Future<ThreadDefinition?> getThread(String name) async {
    final row = await _db.getThread(name);
    if (row == null) return null;
    return _fromRow(row);
  }

  Future<void> deleteThread(int id) => _db.deleteThread(id);

  ThreadDefinition _fromRow(Thread r) {
    return ThreadDefinition(
      id: r.id,
      name: r.name,
      path: r.path,
      contextPrompt: r.contextPrompt,
      enabled: r.enabled,
      status: ThreadStatus.values.firstWhere(
        (s) => s.name == r.status,
        orElse: () => ThreadStatus.idle,
      ),
    );
  }
}
