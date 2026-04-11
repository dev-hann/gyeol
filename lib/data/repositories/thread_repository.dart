import 'package:drift/drift.dart';
import 'package:gyeol/data/database/database.dart';
import 'package:gyeol/data/models/thread_models.dart';

class ThreadRepository {
  ThreadRepository(this._db);
  final AppDatabase _db;

  Future<void> saveThread(ThreadDefinition thread) async {
    await _db.saveThread(
      ThreadsCompanion.insert(
        name: thread.name,
        path: thread.path,
        contextPrompt: Value(thread.contextPrompt),
        enabled: Value(thread.enabled),
        status: Value(thread.status.name),
      ),
    );
    await _db.saveThreadLayers(thread.name, thread.layerNames);
  }

  Future<List<ThreadDefinition>> listThreads() async {
    final rows = await _db.listThreads();
    final allLayers = await _db.listAllThreadLayers();
    final layersByThread = <String, List<String>>{};
    for (final row in allLayers) {
      layersByThread.putIfAbsent(row.threadName, () => []).add(row.layerName);
    }
    return rows.map((r) => _fromRow(r, layersByThread)).toList();
  }

  Stream<List<ThreadDefinition>> watchThreads() {
    return _db.watchThreads().asyncMap((rows) async {
      final allLayers = await _db.listAllThreadLayers();
      final layersByThread = <String, List<String>>{};
      for (final row in allLayers) {
        layersByThread.putIfAbsent(row.threadName, () => []).add(row.layerName);
      }
      return rows.map((r) => _fromRow(r, layersByThread)).toList();
    });
  }

  Future<ThreadDefinition?> getThread(String name) async {
    final row = await _db.getThread(name);
    if (row == null) return null;
    final layers = await _db.listThreadLayers(name);
    return _fromRow(row, {name: layers.map((l) => l.layerName).toList()});
  }

  Future<void> deleteThread(String name) => _db.deleteThread(name);

  ThreadDefinition _fromRow(
    Thread r,
    Map<String, List<String>> layersByThread,
  ) {
    return ThreadDefinition(
      name: r.name,
      path: r.path,
      layerNames: layersByThread[r.name] ?? [],
      contextPrompt: r.contextPrompt,
      enabled: r.enabled,
      status: ThreadStatus.values.firstWhere(
        (s) => s.name == r.status,
        orElse: () => ThreadStatus.idle,
      ),
    );
  }
}
