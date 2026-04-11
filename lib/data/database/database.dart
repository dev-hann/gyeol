import 'dart:convert';

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
    ThreadLayers,
    ChatConversations,
    ChatMessages,
    UiStates,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  AppDatabase.forTesting(super.e);

  static QueryExecutor _openConnection() {
    return driftDatabase(name: 'gyeol.db');
  }

  @override
  int get schemaVersion => 6;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await _createIndexes();
    },
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
        await _recreateLayersV5();
      }
      if (from < 6) {
        await _migrateToV6();
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  Future<void> _createIndexes() async {
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_tasks_status '
      'ON tasks(status)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_tasks_layer '
      'ON tasks(layer_name)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_workers_layer '
      'ON workers(layer_name)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_logs_task '
      'ON execution_logs(task_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_msgs_conv '
      'ON chat_messages(conversation_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_tl_thread '
      'ON thread_layers(thread_name)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_tl_layer '
      'ON thread_layers(layer_name)',
    );
  }

  Future<void> _recreateLayersV5() async {
    await customStatement('''
      CREATE TABLE layers_new (
        name TEXT NOT NULL,
        input_types TEXT NOT NULL,
        output_types TEXT NOT NULL,
        layer_prompt TEXT,
        sort_order INTEGER NOT NULL DEFAULT 0,
        enabled INTEGER NOT NULL DEFAULT 1,
        PRIMARY KEY (name)
      )
    ''');
    await customStatement('''
      INSERT INTO layers_new (name, input_types, output_types, layer_prompt, sort_order, enabled)
      SELECT name, input_types, output_types, layer_prompt, sort_order, enabled
      FROM layers
    ''');
    await customStatement('DROP TABLE layers');
    await customStatement('ALTER TABLE layers_new RENAME TO layers');
  }

  Future<void> _migrateToV6() async {
    final threadRows = await customSelect(
      'SELECT name, layer_names FROM threads',
    ).get();

    await customStatement('''
      CREATE TABLE threads_new (
        name TEXT NOT NULL,
        path TEXT NOT NULL,
        context_prompt TEXT,
        enabled INTEGER NOT NULL DEFAULT 1,
        status TEXT NOT NULL DEFAULT 'idle',
        created_at INTEGER NOT NULL DEFAULT 0,
        updated_at INTEGER NOT NULL DEFAULT 0,
        PRIMARY KEY (name)
      )
    ''');
    await customStatement('''
      INSERT INTO threads_new (name, path, context_prompt, enabled, status)
      SELECT name, path, context_prompt, enabled, status FROM threads
    ''');
    await customStatement('DROP TABLE threads');
    await customStatement('ALTER TABLE threads_new RENAME TO threads');

    await customStatement('''
      CREATE TABLE thread_layers (
        thread_name TEXT NOT NULL REFERENCES threads(name) ON DELETE CASCADE,
        layer_name TEXT NOT NULL REFERENCES layers(name) ON DELETE CASCADE,
        sort_order INTEGER NOT NULL DEFAULT 0,
        PRIMARY KEY (thread_name, layer_name)
      )
    ''');

    for (final row in threadRows) {
      final threadName = row.read<String>('name');
      final layerNamesJson = row.read<String>('layer_names');
      try {
        final decoded = jsonDecode(layerNamesJson);
        if (decoded is List) {
          for (var i = 0; i < decoded.length; i++) {
            if (decoded[i] is String) {
              await customStatement(
                'INSERT INTO thread_layers '
                '(thread_name, layer_name, sort_order) '
                'VALUES (?, ?, ?)',
                [
                  Variable(threadName),
                  Variable(decoded[i] as String),
                  Variable(i),
                ],
              );
            }
          }
        }
      } on FormatException {
        // skip malformed JSON
      }
    }

    await customStatement(
      'ALTER TABLE layers ADD COLUMN created_at INTEGER NOT NULL DEFAULT 0',
    );
    await customStatement(
      'ALTER TABLE layers ADD COLUMN updated_at INTEGER NOT NULL DEFAULT 0',
    );
    await customStatement(
      'ALTER TABLE workers ADD COLUMN created_at INTEGER NOT NULL DEFAULT 0',
    );
    await customStatement(
      'ALTER TABLE workers ADD COLUMN updated_at INTEGER NOT NULL DEFAULT 0',
    );

    await customStatement('''
      CREATE TABLE ui_states (
        key TEXT NOT NULL,
        value TEXT NOT NULL,
        PRIMARY KEY (key)
      )
    ''');
    await customStatement('''
      INSERT INTO ui_states (key, value)
      SELECT key, value FROM settings WHERE key LIKE 'graph_%'
    ''');
    await customStatement("DELETE FROM settings WHERE key LIKE 'graph_%'");

    await _createIndexes();
  }

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

  Future<void> deleteLayer(String name) async {
    await (delete(threadLayers)..where((tl) => tl.layerName.equals(name))).go();
    await (delete(workers)..where((w) => w.layerName.equals(name))).go();
    await (delete(layers)..where((l) => l.name.equals(name))).go();
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

  Future<int> deleteOldExecutionLogs({int olderThanMs = 86400000}) {
    final cutoff = DateTime.now().millisecondsSinceEpoch - olderThanMs;
    return (delete(
      executionLogs,
    )..where((l) => l.createdAt.isSmallerThanValue(cutoff))).go();
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

  Future<void> deleteThread(String name) async {
    await (delete(
      threadLayers,
    )..where((tl) => tl.threadName.equals(name))).go();
    await (delete(threads)..where((t) => t.name.equals(name))).go();
  }

  Future<void> saveThreadLayers(String threadName, List<String> names) async {
    await (delete(
      threadLayers,
    )..where((tl) => tl.threadName.equals(threadName))).go();
    for (var i = 0; i < names.length; i++) {
      await into(threadLayers).insert(
        ThreadLayersCompanion.insert(
          threadName: threadName,
          layerName: names[i],
          sortOrder: Value(i),
        ),
      );
    }
  }

  Future<List<ThreadLayer>> listThreadLayers(String threadName) {
    return (select(threadLayers)
          ..where((tl) => tl.threadName.equals(threadName))
          ..orderBy([(tl) => OrderingTerm.asc(tl.sortOrder)]))
        .get();
  }

  Future<List<ThreadLayer>> listAllThreadLayers() {
    return (select(
      threadLayers,
    )..orderBy([(tl) => OrderingTerm.asc(tl.sortOrder)])).get();
  }

  Stream<List<ThreadLayer>> watchThreadLayers(String threadName) {
    return (select(threadLayers)
          ..where((tl) => tl.threadName.equals(threadName))
          ..orderBy([(tl) => OrderingTerm.asc(tl.sortOrder)]))
        .watch();
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

  Future<void> deleteChatConversation(String id) async {
    await (delete(
      chatMessages,
    )..where((m) => m.conversationId.equals(id))).go();
    await (delete(chatConversations)..where((c) => c.id.equals(id))).go();
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

  Future<void> saveUiState(String key, String value) {
    return into(uiStates).insertOnConflictUpdate(
      UiStatesCompanion(key: Value(key), value: Value(value)),
    );
  }

  Future<String?> getUiState(String key) {
    return (select(uiStates)..where((u) => u.key.equals(key)))
        .getSingleOrNull()
        .then((row) => row?.value);
  }
}
