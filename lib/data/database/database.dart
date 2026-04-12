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
    LayerConnections,
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
  int get schemaVersion => 8;

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
      if (from < 7) {
        await _migrateToV7();
      }
      if (from < 8) {
        await _migrateToV8();
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  Future<void> _createIndexes() async {
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_tasks_status_layer '
      'ON tasks(status, layer_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_tasks_worker '
      'ON tasks(worker_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_tasks_created '
      'ON tasks(created_at)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_tasks_uuid '
      'ON tasks(uuid)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_workers_layer '
      'ON workers(layer_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_logs_task '
      'ON execution_logs(task_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_logs_created '
      'ON execution_logs(created_at)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_msgs_conv '
      'ON chat_messages(conversation_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_msgs_created '
      'ON chat_messages(created_at)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_tl_thread '
      'ON thread_layers(thread_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_tl_layer '
      'ON thread_layers(layer_id)',
    );
    await customStatement(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_conn_unique '
      'ON layer_connections(source_layer_id, target_layer_id)',
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
                [threadName, decoded[i] as String, i],
              );
            }
          }
        }
      } on FormatException {
        // skip
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

  Future<void> _migrateToV7() async {
    await customStatement('''
      CREATE TABLE layers_new (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT UNIQUE NOT NULL,
        input_types TEXT NOT NULL,
        output_types TEXT NOT NULL,
        layer_prompt TEXT,
        sort_order INTEGER NOT NULL DEFAULT 0,
        enabled INTEGER NOT NULL DEFAULT 1,
        created_at INTEGER NOT NULL DEFAULT 0,
        updated_at INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await customStatement('''
      INSERT INTO layers_new (id, name, input_types, output_types,
        layer_prompt, sort_order, enabled, created_at, updated_at)
      SELECT ROW_NUMBER() OVER (ORDER BY sort_order),
        name, input_types, output_types,
        layer_prompt, sort_order, enabled, created_at, updated_at
      FROM layers
    ''');

    await customStatement('DROP TABLE IF EXISTS thread_layers');
    await customStatement('DROP TABLE layers');
    await customStatement('ALTER TABLE layers_new RENAME TO layers');

    final nameToId = <String, int>{};
    final layerRows = await customSelect(
      'SELECT id, name FROM layers ORDER BY id',
    ).get();
    for (final row in layerRows) {
      nameToId[row.read<String>('name')] = row.read<int>('id');
    }

    await customStatement('''
      CREATE TABLE thread_layers_new (
        thread_name TEXT NOT NULL REFERENCES threads(name) ON DELETE CASCADE,
        layer_id INTEGER NOT NULL REFERENCES layers(id) ON DELETE CASCADE,
        sort_order INTEGER NOT NULL DEFAULT 0,
        PRIMARY KEY (thread_name, layer_id)
      )
    ''');
    final tlRows = await customSelect(
      'SELECT thread_name, layer_name, sort_order FROM thread_layers',
    ).get();
    for (final row in tlRows) {
      final tName = row.read<String>('thread_name');
      final lName = row.read<String>('layer_name');
      final sort = row.read<int>('sort_order');
      final lId = nameToId[lName];
      if (lId != null) {
        await customStatement(
          'INSERT INTO thread_layers_new '
          '(thread_name, layer_id, sort_order) VALUES (?, ?, ?)',
          [tName, lId, sort],
        );
      }
    }
    await customStatement('DROP TABLE thread_layers');
    await customStatement(
      'ALTER TABLE thread_layers_new RENAME TO thread_layers',
    );

    await customStatement('''
      CREATE TABLE layer_connections (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        source_layer_id INTEGER NOT NULL REFERENCES layers(id) ON DELETE CASCADE,
        target_layer_id INTEGER NOT NULL REFERENCES layers(id) ON DELETE CASCADE
      )
    ''');

    for (var si = 0; si < layerRows.length; si++) {
      final src = layerRows[si];
      final srcId = src.read<int>('id');
      List<String> srcOutputs;
      try {
        final d = jsonDecode(src.read<String>('output_types'));
        srcOutputs = d is List ? d.whereType<String>().toList() : <String>[];
      } on FormatException {
        srcOutputs = <String>[];
      }

      for (var di = 0; di < layerRows.length; di++) {
        if (si == di) continue;
        final dst = layerRows[di];
        final dstId = dst.read<int>('id');
        List<String> dstInputs;
        try {
          final d = jsonDecode(dst.read<String>('input_types'));
          dstInputs = d is List ? d.whereType<String>().toList() : <String>[];
        } on FormatException {
          dstInputs = <String>[];
        }
        if (srcOutputs.toSet().intersection(dstInputs.toSet()).isNotEmpty) {
          await customStatement(
            'INSERT INTO layer_connections '
            '(source_layer_id, target_layer_id) VALUES (?, ?)',
            [srcId, dstId],
          );
        }
      }
    }

    await customStatement('ALTER TABLE workers ADD COLUMN layer_id INTEGER');
    for (final entry in nameToId.entries) {
      await customStatement(
        'UPDATE workers SET layer_id = ? WHERE layer_name = ?',
        [entry.value, entry.key],
      );
    }

    await customStatement('ALTER TABLE tasks ADD COLUMN layer_id INTEGER');
    for (final entry in nameToId.entries) {
      await customStatement(
        'UPDATE tasks SET layer_id = ? WHERE layer_name = ?',
        [entry.value, entry.key],
      );
    }

    await _createIndexes();
  }

  Future<void> _migrateToV8() async {
    await customStatement('BEGIN TRANSACTION');
    try {
      final layerNameToId = <String, int>{};
      final layerRows = await customSelect(
        'SELECT id, name FROM layers ORDER BY id',
      ).get();
      for (final row in layerRows) {
        layerNameToId[row.read<String>('name')] = row.read<int>('id');
      }

      final workerNameToId = <String, int>{};

      await customStatement('''
        CREATE TABLE workers_new (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT UNIQUE NOT NULL,
          layer_id INTEGER NOT NULL REFERENCES layers(id) ON DELETE CASCADE,
          system_prompt TEXT NOT NULL,
          model TEXT,
          temperature REAL,
          max_tokens INTEGER,
          enabled INTEGER NOT NULL DEFAULT 1,
          created_at INTEGER NOT NULL DEFAULT 0,
          updated_at INTEGER NOT NULL DEFAULT 0
        )
      ''');
      await customStatement('''
        INSERT INTO workers_new (name, layer_id, system_prompt, model,
          temperature, max_tokens, enabled, created_at, updated_at)
        SELECT name, layer_id, system_prompt, model,
          temperature, max_tokens, enabled, created_at, updated_at
        FROM workers
      ''');
      final wRows = await customSelect(
        'SELECT rowid, name FROM workers_new ORDER BY rowid',
      ).get();
      for (final row in wRows) {
        workerNameToId[row.read<String>('name')] = row.read<int>('rowid');
      }
      await customStatement('DROP TABLE workers');
      await customStatement('ALTER TABLE workers_new RENAME TO workers');

      await customStatement('''
        CREATE TABLE tasks_new (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          uuid TEXT UNIQUE NOT NULL,
          task_type TEXT NOT NULL,
          payload TEXT NOT NULL,
          priority TEXT NOT NULL,
          status TEXT NOT NULL,
          retry_count INTEGER NOT NULL DEFAULT 0,
          max_retries INTEGER NOT NULL DEFAULT 3,
          depth INTEGER NOT NULL DEFAULT 0,
          parent_task_id INTEGER REFERENCES tasks(id) ON DELETE CASCADE,
          layer_id INTEGER REFERENCES layers(id) ON DELETE SET NULL,
          worker_id INTEGER REFERENCES workers(id) ON DELETE SET NULL,
          created_at INTEGER NOT NULL DEFAULT 0,
          updated_at INTEGER NOT NULL DEFAULT 0
        )
      ''');
      await customStatement('''
        INSERT INTO tasks_new (uuid, task_type, payload, priority, status,
          retry_count, max_retries, depth, layer_id, created_at, updated_at)
        SELECT id, task_type, payload, priority, status,
          retry_count, max_retries, depth, layer_id, created_at, updated_at
        FROM tasks
      ''');

      final oldTaskRows = await customSelect(
        'SELECT rowid AS old_id, id AS old_uuid FROM tasks ORDER BY rowid',
      ).get();
      final oldToNewTaskId = <String, int>{};
      for (final row in oldTaskRows) {
        oldToNewTaskId[row.read<String>('old_uuid')] = row.read<int>('old_id');
      }

      final parentRows = await customSelect(
        'SELECT t.rowid AS new_id, t.parent_task_id AS old_parent_uuid '
        'FROM tasks t WHERE t.parent_task_id IS NOT NULL',
      ).get();
      for (final row in parentRows) {
        final newId = row.read<int>('new_id');
        final oldParentUuid = row.read<String>('old_parent_uuid');
        final newParentId = oldToNewTaskId[oldParentUuid];
        if (newParentId != null) {
          await customStatement(
            'UPDATE tasks_new SET parent_task_id = ? WHERE rowid = ?',
            [newParentId, newId],
          );
        }
      }

      final taskWorkerRows = await customSelect(
        'SELECT t.rowid AS new_id, t.worker_name '
        'FROM tasks t WHERE t.worker_name IS NOT NULL',
      ).get();
      for (final row in taskWorkerRows) {
        final newId = row.read<int>('new_id');
        final wName = row.read<String>('worker_name');
        final wId = workerNameToId[wName];
        if (wId != null) {
          await customStatement(
            'UPDATE tasks_new SET worker_id = ? WHERE rowid = ?',
            [wId, newId],
          );
        }
      }

      await customStatement('DROP TABLE tasks');
      await customStatement('ALTER TABLE tasks_new RENAME TO tasks');

      final threadNameToId = <String, int>{};

      await customStatement('''
        CREATE TABLE threads_new (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT UNIQUE NOT NULL,
          path TEXT NOT NULL,
          context_prompt TEXT,
          enabled INTEGER NOT NULL DEFAULT 1,
          status TEXT NOT NULL DEFAULT 'idle',
          created_at INTEGER NOT NULL DEFAULT 0,
          updated_at INTEGER NOT NULL DEFAULT 0
        )
      ''');
      await customStatement('''
        INSERT INTO threads_new (name, path, context_prompt, enabled, status,
          created_at, updated_at)
        SELECT name, path, context_prompt, enabled, status,
          created_at, updated_at
        FROM threads
      ''');
      final thRows = await customSelect(
        'SELECT rowid, name FROM threads_new ORDER BY rowid',
      ).get();
      for (final row in thRows) {
        threadNameToId[row.read<String>('name')] = row.read<int>('rowid');
      }
      await customStatement('DROP TABLE threads');
      await customStatement('ALTER TABLE threads_new RENAME TO threads');

      await customStatement('''
        CREATE TABLE thread_layers_new (
          thread_id INTEGER NOT NULL REFERENCES threads(id) ON DELETE CASCADE,
          layer_id INTEGER NOT NULL REFERENCES layers(id) ON DELETE CASCADE,
          sort_order INTEGER NOT NULL DEFAULT 0,
          PRIMARY KEY (thread_id, layer_id)
        )
      ''');
      final tlRows = await customSelect(
        'SELECT thread_name, layer_id, sort_order FROM thread_layers',
      ).get();
      for (final row in tlRows) {
        final tName = row.read<String>('thread_name');
        final lId = row.read<int>('layer_id');
        final sort = row.read<int>('sort_order');
        final tId = threadNameToId[tName];
        if (tId != null) {
          await customStatement(
            'INSERT INTO thread_layers_new '
            '(thread_id, layer_id, sort_order) VALUES (?, ?, ?)',
            [tId, lId, sort],
          );
        }
      }
      await customStatement('DROP TABLE thread_layers');
      await customStatement(
        'ALTER TABLE thread_layers_new RENAME TO thread_layers',
      );

      final taskUuidToNewId = <String, int>{};
      final taskNewRows = await customSelect(
        'SELECT id, uuid FROM tasks ORDER BY id',
      ).get();
      for (final row in taskNewRows) {
        taskUuidToNewId[row.read<String>('uuid')] = row.read<int>('id');
      }

      await customStatement('''
        CREATE TABLE execution_logs_new (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          task_id INTEGER NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
          worker_id INTEGER,
          status TEXT NOT NULL,
          message TEXT,
          created_at INTEGER NOT NULL DEFAULT 0
        )
      ''');
      final logRows = await customSelect(
        'SELECT task_id AS old_task_uuid, worker_name, status, message, '
        'created_at FROM execution_logs ORDER BY rowid',
      ).get();
      for (final row in logRows) {
        final oldTaskUuid = row.read<String>('old_task_uuid');
        final newTaskId = taskUuidToNewId[oldTaskUuid];
        if (newTaskId == null) continue;
        final wName = row.read<String?>('worker_name');
        final wId = wName != null ? workerNameToId[wName] : null;
        await customStatement(
          'INSERT INTO execution_logs_new '
          '(task_id, worker_id, status, message, created_at) '
          'VALUES (?, ?, ?, ?, ?)',
          [
            newTaskId,
            wId,
            row.read<String>('status'),
            row.read<String?>('message'),
            row.read<int>('created_at'),
          ],
        );
      }
      await customStatement('DROP TABLE execution_logs');
      await customStatement(
        'ALTER TABLE execution_logs_new RENAME TO execution_logs',
      );

      await customStatement('''
        CREATE UNIQUE INDEX IF NOT EXISTS idx_conn_unique
        ON layer_connections(source_layer_id, target_layer_id)
      ''');

      await customStatement('''
        CREATE INDEX IF NOT EXISTS idx_tasks_status_layer
        ON tasks(status, layer_id)
      ''');
      await customStatement('''
        CREATE INDEX IF NOT EXISTS idx_tasks_worker
        ON tasks(worker_id)
      ''');
      await customStatement('''
        CREATE INDEX IF NOT EXISTS idx_tasks_created
        ON tasks(created_at)
      ''');
      await customStatement('''
        CREATE INDEX IF NOT EXISTS idx_tasks_uuid
        ON tasks(uuid)
      ''');
      await customStatement('''
        CREATE INDEX IF NOT EXISTS idx_logs_created
        ON execution_logs(created_at)
      ''');
      await customStatement('''
        CREATE INDEX IF NOT EXISTS idx_msgs_created
        ON chat_messages(created_at)
      ''');

      await customStatement('DROP INDEX IF EXISTS idx_tasks_status');
      await customStatement('DROP INDEX IF EXISTS idx_tasks_layer');
      await customStatement('DROP INDEX IF EXISTS idx_conn_src');
      await customStatement('DROP INDEX IF EXISTS idx_conn_dst');

      await customStatement('COMMIT');
    } catch (e) {
      await customStatement('ROLLBACK');
      rethrow;
    }
  }

  Future<void> saveTask(TasksCompanion task) {
    return into(tasks).insertOnConflictUpdate(task);
  }

  Future<Task?> getTask(String uuid) {
    return (select(tasks)..where((t) => t.uuid.equals(uuid))).getSingleOrNull();
  }

  Future<Task?> getTaskById(int id) {
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

  Future<void> deleteLayer(int id) async {
    await (delete(layers)..where((l) => l.id.equals(id))).go();
  }

  Future<void> saveWorker(WorkersCompanion worker) {
    return into(workers).insertOnConflictUpdate(worker);
  }

  Future<Worker?> getWorker(String name) {
    return (select(
      workers,
    )..where((w) => w.name.equals(name))).getSingleOrNull();
  }

  Future<Worker?> getWorkerById(int id) {
    return (select(workers)..where((w) => w.id.equals(id))).getSingleOrNull();
  }

  Future<List<Worker>> listWorkers() {
    return select(workers).get();
  }

  Stream<List<Worker>> watchWorkers() {
    return select(workers).watch();
  }

  Future<void> deleteWorker(int id) {
    return (delete(workers)..where((w) => w.id.equals(id))).go();
  }

  Future<void> saveConnection(LayerConnectionsCompanion conn) {
    return into(layerConnections).insert(
      conn,
      onConflict: DoUpdate(
        (old) => conn,
        target: [
          layerConnections.sourceLayerId,
          layerConnections.targetLayerId,
        ],
      ),
    );
  }

  Future<void> deleteConnection(int sourceLayerId, int targetLayerId) {
    return (delete(layerConnections)..where(
          (c) =>
              c.sourceLayerId.equals(sourceLayerId) &
              c.targetLayerId.equals(targetLayerId),
        ))
        .go();
  }

  Future<void> deleteConnectionsByLayerId(int layerId) {
    return (delete(layerConnections)..where(
          (c) =>
              c.sourceLayerId.equals(layerId) | c.targetLayerId.equals(layerId),
        ))
        .go();
  }

  Future<List<LayerConnection>> listConnections() {
    return select(layerConnections).get();
  }

  Stream<List<LayerConnection>> watchConnections() {
    return select(layerConnections).watch();
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
    required int taskId,
    required String status,
    int? workerId,
    String? message,
  }) {
    return into(executionLogs).insert(
      ExecutionLogsCompanion.insert(
        taskId: taskId,
        workerId: Value(workerId),
        status: status,
        message: Value(message),
        createdAt: Value(DateTime.now().millisecondsSinceEpoch),
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

  Future<Thread?> getThreadById(int id) {
    return (select(threads)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<void> deleteThread(int id) async {
    await (delete(threadLayers)..where((tl) => tl.threadId.equals(id))).go();
    await (delete(threads)..where((t) => t.id.equals(id))).go();
  }

  Future<void> saveThreadLayerIds(int threadId, List<int> ids) async {
    await (delete(
      threadLayers,
    )..where((tl) => tl.threadId.equals(threadId))).go();
    for (var i = 0; i < ids.length; i++) {
      await into(threadLayers).insert(
        ThreadLayersCompanion.insert(
          threadId: threadId,
          layerId: ids[i],
          sortOrder: Value(i),
        ),
      );
    }
  }

  Future<List<ThreadLayer>> listThreadLayers(int threadId) {
    return (select(threadLayers)
          ..where((tl) => tl.threadId.equals(threadId))
          ..orderBy([(tl) => OrderingTerm.asc(tl.sortOrder)]))
        .get();
  }

  Future<List<ThreadLayer>> listAllThreadLayers() {
    return (select(
      threadLayers,
    )..orderBy([(tl) => OrderingTerm.asc(tl.sortOrder)])).get();
  }

  Stream<List<ThreadLayer>> watchThreadLayers(int threadId) {
    return (select(threadLayers)
          ..where((tl) => tl.threadId.equals(threadId))
          ..orderBy([(tl) => OrderingTerm.asc(tl.sortOrder)]))
        .watch();
  }

  Future<List<ExecutionLog>> listExecutionLogs({int? taskId, int limit = 200}) {
    final query = select(executionLogs)
      ..orderBy([(l) => OrderingTerm.desc(l.createdAt)])
      ..limit(limit);
    if (taskId != null) {
      query.where((l) => l.taskId.equals(taskId));
    }
    return query.get();
  }

  Stream<List<ExecutionLog>> watchExecutionLogs({
    int? taskId,
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
