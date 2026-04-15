import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gyeol/data/database/database.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  Future<Set<String>> tableColumns(String table) async {
    final rows = await db.customSelect('PRAGMA table_info($table)').get();
    return rows.map((r) => r.read<String>('name')).toSet();
  }

  Future<Map<String, String>> columnTypes(String table) async {
    final rows = await db.customSelect('PRAGMA table_info($table)').get();
    return {
      for (final r in rows) r.read<String>('name'): r.read<String>('type'),
    };
  }

  Future<Map<String, String?>> columnDefaults(String table) async {
    final rows = await db.customSelect('PRAGMA table_info($table)').get();
    return {
      for (final r in rows)
        r.read<String>('name'): r.read<String?>('dflt_value'),
    };
  }

  group('app_database table existence', () {
    test('all 10 tables exist in schema', () async {
      final rows = await db
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name",
          )
          .get();
      final tables = rows.map((r) => r.read<String>('name')).toSet();

      expect(
        tables,
        containsAll([
          'tasks',
          'layers',
          'workers',
          'settings',
          'threads',
          'layer_connections',
          'execution_logs',
          'chat_conversations',
          'chat_messages',
          'ui_states',
        ]),
      );
    });
  });

  group('tasks table schema', () {
    test('has all expected columns', () async {
      final cols = await tableColumns('tasks');

      expect(
        cols,
        containsAll([
          'id',
          'uuid',
          'task_type',
          'payload',
          'priority',
          'status',
          'retry_count',
          'max_retries',
          'depth',
          'parent_task_id',
          'layer_id',
          'worker_id',
          'thread_id',
          'created_at',
          'updated_at',
        ]),
      );
      expect(cols.length, 15);
    });

    test('column types are correct', () async {
      final types = await columnTypes('tasks');

      expect(types['id'], 'INTEGER');
      expect(types['uuid'], 'TEXT');
      expect(types['task_type'], 'TEXT');
      expect(types['payload'], 'TEXT');
      expect(types['priority'], 'TEXT');
      expect(types['status'], 'TEXT');
      expect(types['retry_count'], 'INTEGER');
      expect(types['depth'], 'INTEGER');
      expect(types['created_at'], 'INTEGER');
    });

    test('default values are correct', () async {
      final defaults = await columnDefaults('tasks');

      expect(defaults['retry_count'], '0');
      expect(defaults['max_retries'], '3');
      expect(defaults['depth'], '0');
      expect(defaults['created_at'], '0');
      expect(defaults['updated_at'], '0');
    });
  });

  group('layers table schema', () {
    test('has all expected columns', () async {
      final cols = await tableColumns('layers');

      expect(
        cols,
        containsAll([
          'id',
          'thread_id',
          'name',
          'input_types',
          'output_types',
          'layer_prompt',
          'sort_order',
          'enabled',
          'created_at',
          'updated_at',
        ]),
      );
      expect(cols.length, 10);
    });

    test('default values are correct', () async {
      final defaults = await columnDefaults('layers');

      expect(defaults['sort_order'], '0');
      expect(defaults['enabled'], '1');
      expect(defaults['created_at'], '0');
      expect(defaults['updated_at'], '0');
    });
  });

  group('workers table schema', () {
    test('has all expected columns', () async {
      final cols = await tableColumns('workers');

      expect(
        cols,
        containsAll([
          'id',
          'name',
          'layer_id',
          'system_prompt',
          'model',
          'temperature',
          'max_tokens',
          'enabled',
          'created_at',
          'updated_at',
        ]),
      );
      expect(cols.length, 10);
    });

    test('column types are correct', () async {
      final types = await columnTypes('workers');

      expect(types['id'], 'INTEGER');
      expect(types['name'], 'TEXT');
      expect(types['system_prompt'], 'TEXT');
      expect(types['temperature'], 'REAL');
      expect(types['max_tokens'], 'INTEGER');
    });

    test('default values are correct', () async {
      final defaults = await columnDefaults('workers');

      expect(defaults['enabled'], '1');
      expect(defaults['created_at'], '0');
      expect(defaults['updated_at'], '0');
    });
  });

  group('threads table schema', () {
    test('has all expected columns', () async {
      final cols = await tableColumns('threads');

      expect(
        cols,
        containsAll([
          'id',
          'name',
          'path',
          'context_prompt',
          'enabled',
          'status',
          'created_at',
          'updated_at',
        ]),
      );
      expect(cols.length, 8);
    });

    test('default values are correct', () async {
      final defaults = await columnDefaults('threads');

      expect(defaults['enabled'], '1');
      expect(defaults['status'], "'idle'");
      expect(defaults['created_at'], '0');
      expect(defaults['updated_at'], '0');
    });
  });

  group('settings table schema', () {
    test('has key and value columns', () async {
      final cols = await tableColumns('settings');

      expect(cols, containsAll(['key', 'value']));
      expect(cols.length, 2);
    });

    test('primary key is on key column', () async {
      final rows = await db.customSelect('PRAGMA table_info(settings)').get();
      final keyCol = rows.firstWhere((r) => r.read<String>('name') == 'key');

      expect(keyCol.read<int>('pk'), 1);
    });
  });

  group('layer_connections table schema', () {
    test('has all expected columns', () async {
      final cols = await tableColumns('layer_connections');

      expect(cols, containsAll(['id', 'source_layer_id', 'target_layer_id']));
      expect(cols.length, 3);
    });
  });

  group('execution_logs table schema', () {
    test('has all expected columns', () async {
      final cols = await tableColumns('execution_logs');

      expect(
        cols,
        containsAll([
          'id',
          'task_id',
          'worker_id',
          'status',
          'message',
          'created_at',
        ]),
      );
      expect(cols.length, 6);
    });
  });

  group('chat_conversations table schema', () {
    test('has all expected columns', () async {
      final cols = await tableColumns('chat_conversations');

      expect(cols, containsAll(['id', 'title', 'created_at', 'updated_at']));
      expect(cols.length, 4);
    });

    test('primary key is text id', () async {
      final rows = await db
          .customSelect('PRAGMA table_info(chat_conversations)')
          .get();
      final idCol = rows.firstWhere((r) => r.read<String>('name') == 'id');

      expect(idCol.read<int>('pk'), 1);
      expect(idCol.read<String>('type'), 'TEXT');
    });
  });

  group('chat_messages table schema', () {
    test('has all expected columns', () async {
      final cols = await tableColumns('chat_messages');

      expect(
        cols,
        containsAll([
          'id',
          'conversation_id',
          'role',
          'content',
          'tool_name',
          'tool_call_id',
          'created_at',
        ]),
      );
      expect(cols.length, 7);
    });

    test('primary key is text id', () async {
      final rows = await db
          .customSelect('PRAGMA table_info(chat_messages)')
          .get();
      final idCol = rows.firstWhere((r) => r.read<String>('name') == 'id');

      expect(idCol.read<int>('pk'), 1);
      expect(idCol.read<String>('type'), 'TEXT');
    });
  });

  group('ui_states table schema', () {
    test('has key and value columns', () async {
      final cols = await tableColumns('ui_states');

      expect(cols, containsAll(['key', 'value']));
      expect(cols.length, 2);
    });

    test('primary key is on key column', () async {
      final rows = await db.customSelect('PRAGMA table_info(ui_states)').get();
      final keyCol = rows.firstWhere((r) => r.read<String>('name') == 'key');

      expect(keyCol.read<int>('pk'), 1);
    });
  });
}
