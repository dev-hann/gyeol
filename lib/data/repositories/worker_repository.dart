import 'package:drift/drift.dart';
import 'package:gyeol/data/database/database.dart';
import 'package:gyeol/data/models/worker_models.dart';

class WorkerRepository {
  WorkerRepository(this._db);
  final AppDatabase _db;

  Future<void> saveWorker(WorkerDefinition worker) {
    return _db.saveWorker(
      WorkersCompanion.insert(
        name: worker.name,
        layerName: worker.layerName,
        systemPrompt: worker.systemPrompt,
        model: Value(worker.model),
        temperature: Value(worker.temperature),
        maxTokens: Value(worker.maxTokens),
        enabled: Value(worker.enabled),
      ),
    );
  }

  Future<WorkerDefinition?> getWorker(String name) async {
    final row = await _db.getWorker(name);
    return row != null ? _workerFromRow(row) : null;
  }

  Future<List<WorkerDefinition>> listWorkers() async {
    final rows = await _db.listWorkers();
    return rows.map(_workerFromRow).toList();
  }

  Stream<List<WorkerDefinition>> watchWorkers() {
    return _db.watchWorkers().map((rows) => rows.map(_workerFromRow).toList());
  }

  Future<void> deleteWorker(String name) => _db.deleteWorker(name);

  WorkerDefinition _workerFromRow(Worker r) {
    return WorkerDefinition(
      name: r.name,
      layerName: r.layerName,
      systemPrompt: r.systemPrompt,
      model: r.model,
      temperature: r.temperature,
      maxTokens: r.maxTokens,
      enabled: r.enabled,
    );
  }
}
