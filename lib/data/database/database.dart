import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'package:gyeol/data/database/app_database.dart';

part 'database.g.dart';

@DriftDatabase(
  tables: [
    Tasks,
    Layers,
    Workers,
    Settings,
    ExecutionLogs,
    Threads,
    ChatConversations,
    ChatMessages,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  AppDatabase.forTesting(super.e);

  static QueryExecutor _openConnection() {
    return driftDatabase(name: 'gyeol.db');
  }

  @override
  int get schemaVersion => 5;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.createTable(threads);
      }
      if (from < 3) {
        await customStatement(
          'ALTER TABLE threads ADD COLUMN context_prompt TEXT',
        );
        await customStatement(
          'ALTER TABLE layers ADD COLUMN layer_prompt TEXT',
        );
      }
      if (from < 4) {
        await m.createTable(chatConversations);
        await m.createTable(chatMessages);
      }
      if (from < 5) {
        await customStatement('ALTER TABLE layers DROP COLUMN worker_names');
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

  Stream<List<Task>> watchTasks({int limit = 100, int offset = 0}) {
    return (select(tasks)
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
          ..limit(limit, offset: offset))
        .watch();
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

  Stream<List<Layer>> watchLayers() {
    return (select(
      layers,
    )..orderBy([(l) => OrderingTerm.asc(l.sortOrder)])).watch();
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

  Stream<List<Worker>> watchWorkers() {
    return select(workers).watch();
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

  Stream<List<Thread>> watchThreads() {
    return select(threads).watch();
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

  Stream<List<ExecutionLog>> watchExecutionLogs({
    String? taskId,
    int limit = 200,
  }) {
    final query = select(executionLogs)
      ..orderBy([(l) => OrderingTerm.desc(l.createdAt)])
      ..limit(limit);
    if (taskId != null) {
      query.where((l) => l.taskId.equals(taskId));
    }
    return query.watch();
  }

  Future<void> saveChatConversation(ChatConversationsCompanion conv) {
    return into(chatConversations).insertOnConflictUpdate(conv);
  }

  Future<List<ChatConversationRow>> listChatConversations() {
    return (select(
      chatConversations,
    )..orderBy([(c) => OrderingTerm.desc(c.updatedAt)])).get();
  }

  Stream<List<ChatConversationRow>> watchChatConversations() {
    return (select(
      chatConversations,
    )..orderBy([(c) => OrderingTerm.desc(c.updatedAt)])).watch();
  }

  Future<void> deleteChatConversation(String id) {
    return (delete(chatConversations)..where((c) => c.id.equals(id))).go();
  }

  Future<void> saveChatMessage(ChatMessagesCompanion msg) {
    return into(chatMessages).insertOnConflictUpdate(msg);
  }

  Future<List<ChatMessageRow>> listChatMessages(String conversationId) {
    return (select(chatMessages)
          ..where((m) => m.conversationId.equals(conversationId))
          ..orderBy([(m) => OrderingTerm.asc(m.createdAt)]))
        .get();
  }

  Stream<List<ChatMessageRow>> watchChatMessages(String conversationId) {
    return (select(chatMessages)
          ..where((m) => m.conversationId.equals(conversationId))
          ..orderBy([(m) => OrderingTerm.asc(m.createdAt)]))
        .watch();
  }

  Future<void> deleteChatMessage(String id) {
    return (delete(chatMessages)..where((m) => m.id.equals(id))).go();
  }

  Future<void> deleteChatMessagesByConversation(String conversationId) {
    return (delete(
      chatMessages,
    )..where((m) => m.conversationId.equals(conversationId))).go();
  }

  Future<void> updateChatConversationTitle(String id, String title) {
    return (update(chatConversations)..where((c) => c.id.equals(id))).write(
      ChatConversationsCompanion(
        title: Value(title),
        updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
      ),
    );
  }
}
