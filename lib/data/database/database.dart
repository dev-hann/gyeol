import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'package:gyeol/data/database/app_database.dart';

part 'database.g.dart';

@DriftDatabase(
  tables: [Tasks, Layers, Workers, Settings, ExecutionLogs, Threads],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  AppDatabase.forTesting(super.e);

  static QueryExecutor _openConnection() {
    return driftDatabase(name: 'gyeol.db');
  }

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.createTable(threads);
      }
    },
  );

  Future<void> saveTask(TasksCompanion task) {
    return into(tasks).insertOnConflictUpdate(task);
  }

  Future<Task?> getTask(String id) {
    return (select(tasks)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<List<Task>> listTasks({int limit = 100, int offset = 0}) {
    return (select(tasks)
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
          ..limit(limit, offset: offset))
        .get();
  }

  Future<int> getQueueSize() async {
    final countExpr = countAll();
    final query = selectOnly(tasks)
      ..addColumns([countExpr])
      ..where(tasks.status.equals('pending'));
    final row = await query.getSingle();
    return row.read(countExpr) ?? 0;
  }

  Future<void> saveLayer(LayersCompanion layer) {
    return into(layers).insertOnConflictUpdate(layer);
  }

  Future<List<Layer>> listLayers() {
    return (select(
      layers,
    )..orderBy([(l) => OrderingTerm.asc(l.sortOrder)])).get();
  }

  Future<void> deleteLayer(String name) {
    return (delete(layers)..where((l) => l.name.equals(name))).go();
  }

  Future<void> saveWorker(WorkersCompanion worker) {
    return into(workers).insertOnConflictUpdate(worker);
  }

  Future<Worker?> getWorker(String name) {
    return (select(
      workers,
    )..where((w) => w.name.equals(name))).getSingleOrNull();
  }

  Future<List<Worker>> listWorkers() {
    return select(workers).get();
  }

  Future<void> deleteWorker(String name) {
    return (delete(workers)..where((w) => w.name.equals(name))).go();
  }

  Future<void> saveSettings(String json) {
    return into(settings).insertOnConflictUpdate(
      SettingsCompanion(key: const Value('provider'), value: Value(json)),
    );
  }

  Future<String?> getSettingsJson() {
    return (select(settings)..where((s) => s.key.equals('provider')))
        .getSingleOrNull()
        .then((row) => row?.value);
  }

  Future<void> saveJsonValue(String key, String json) {
    return into(settings).insertOnConflictUpdate(
      SettingsCompanion(key: Value(key), value: Value(json)),
    );
  }

  Future<String?> getJsonValue(String key) {
    return (select(settings)..where((s) => s.key.equals(key)))
        .getSingleOrNull()
        .then((row) => row?.value);
  }

  Future<void> logExecution({
    required String taskId,
    required String status,
    String? workerName,
    String? message,
  }) {
    return into(executionLogs).insert(
      ExecutionLogsCompanion.insert(
        taskId: taskId,
        workerName: Value(workerName),
        status: status,
        message: Value(message),
        createdAt: DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  Future<void> saveThread(ThreadsCompanion thread) {
    return into(threads).insertOnConflictUpdate(thread);
  }

  Future<List<Thread>> listThreads() {
    return select(threads).get();
  }

  Future<Thread?> getThread(String name) {
    return (select(
      threads,
    )..where((t) => t.name.equals(name))).getSingleOrNull();
  }

  Future<void> deleteThread(String name) {
    return (delete(threads)..where((t) => t.name.equals(name))).go();
  }

  Future<List<ExecutionLog>> listExecutionLogs({
    String? taskId,
    int limit = 200,
  }) {
    final query = select(executionLogs)
      ..orderBy([(l) => OrderingTerm.desc(l.createdAt)])
      ..limit(limit);
    if (taskId != null) {
      query.where((l) => l.taskId.equals(taskId));
    }
    return query.get();
  }
}
