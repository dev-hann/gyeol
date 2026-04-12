import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gyeol/data/database/database.dart';
import 'package:gyeol/data/models/task_models.dart';
import 'package:gyeol/data/providers/core_providers.dart';
import 'package:gyeol/data/providers/logs_provider.dart';

class _ErrorInjectDb extends AppDatabase {
  _ErrorInjectDb(this.controller) : super.forTesting(NativeDatabase.memory());

  final StreamController<List<ExecutionLog>> controller;

  @override
  Stream<List<ExecutionLog>> watchExecutionLogs({
    int? taskId,
    int limit = 200,
  }) => controller.stream;
}

void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  group('LogsNotifier', () {
    test('build returns empty list when no logs', () async {
      final logs = await container.read(logsProvider.future);
      expect(logs, isEmpty);
    });

    test('build returns logs after insertion', () async {
      final repo = container.read(repositoryProvider);
      final taskId = await repo.tasks.createTask(
        'parse',
        '{}',
        TaskPriority.high,
      );

      await repo.logs.logExecution(
        taskId: taskId,
        status: 'running',
        message: 'started',
      );

      await Future<void>.delayed(const Duration(milliseconds: 100));
      final logs = await container.read(logsProvider.future);
      expect(logs, hasLength(1));
      expect(logs.first.taskId, taskId);
      expect(logs.first.status, 'running');
      expect(logs.first.message, 'started');
    });

    test('build watches stream and updates on new log', () async {
      final repo = container.read(repositoryProvider);
      final taskId = await repo.tasks.createTask(
        'parse',
        '{}',
        TaskPriority.medium,
      );

      final logs0 = await container.read(logsProvider.future);
      expect(logs0, isEmpty);

      await repo.logs.logExecution(
        taskId: taskId,
        status: 'completed',
        message: 'done',
      );

      await Future<void>.delayed(const Duration(milliseconds: 150));
      final logs1 = await container.read(logsProvider.future);
      expect(logs1, hasLength(1));
      expect(logs1.first.status, 'completed');
    });

    test('build orders logs by createdAt descending', () async {
      final repo = container.read(repositoryProvider);
      final taskId = await repo.tasks.createTask(
        'parse',
        '{}',
        TaskPriority.low,
      );

      await repo.logs.logExecution(
        taskId: taskId,
        status: 'running',
        message: 'first',
      );
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await repo.logs.logExecution(
        taskId: taskId,
        status: 'completed',
        message: 'second',
      );

      await Future<void>.delayed(const Duration(milliseconds: 150));
      final logs = await container.read(logsProvider.future);
      expect(logs, hasLength(2));
      expect(logs.first.status, 'completed');
      expect(logs.last.status, 'running');
    });

    test('stream error transitions state to AsyncError', () async {
      final controller = StreamController<List<ExecutionLog>>();
      final errDb = _ErrorInjectDb(controller);
      final errContainer = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(errDb)],
      );

      await errContainer.read(logsProvider.future);
      controller.addError(StateError('db broken'));
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final state = errContainer.read(logsProvider);
      expect(state.hasError, isTrue);

      await controller.close();
      errContainer.dispose();
      await errDb.close();
    });

    test('stream subscription is cancelled on dispose', () async {
      final container1 = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)],
      );

      await container1.read(logsProvider.future);
      container1.dispose();

      final container2 = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)],
      );

      final logs = await container2.read(logsProvider.future);
      expect(logs, isEmpty);

      container2.dispose();
    });
  });
}
