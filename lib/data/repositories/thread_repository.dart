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
    final row = await _db.getThread(thread.name);
    final threadId = row?.id ?? thread.id;
    await _db.saveThreadLayerIds(threadId, thread.layerIds);
  }

  Future<List<ThreadDefinition>> listThreads() async {
    final rows = await _db.listThreads();
    final allLayers = await _db.listAllThreadLayers();
    final layersByThread = <int, List<int>>{};
    for (final row in allLayers) {
      layersByThread.putIfAbsent(row.threadId, () => []).add(row.layerId);
    }
    return rows.map((r) => _fromRow(r, layersByThread)).toList();
  }

  Stream<List<ThreadDefinition>> watchThreads() {
    return _db.watchThreads().asyncMap((rows) async {
      final allLayers = await _db.listAllThreadLayers();
      final layersByThread = <int, List<int>>{};
      for (final row in allLayers) {
        layersByThread.putIfAbsent(row.threadId, () => []).add(row.layerId);
      }
      return rows.map((r) => _fromRow(r, layersByThread)).toList();
    });
  }

  Future<ThreadDefinition?> getThread(String name) async {
    final row = await _db.getThread(name);
    if (row == null) return null;
    final layers = await _db.listThreadLayers(row.id);
    return _fromRow(row, {row.id: layers.map((l) => l.layerId).toList()});
  }

  Future<void> deleteThread(int id) => _db.deleteThread(id);

  ThreadDefinition _fromRow(Thread r, Map<int, List<int>> layersByThread) {
    return ThreadDefinition(
      id: r.id,
      name: r.name,
      path: r.path,
      layerIds: layersByThread[r.id] ?? [],
      contextPrompt: r.contextPrompt,
      enabled: r.enabled,
      status: ThreadStatus.values.firstWhere(
        (s) => s.name == r.status,
        orElse: () => ThreadStatus.idle,
      ),
    );
  }
}
