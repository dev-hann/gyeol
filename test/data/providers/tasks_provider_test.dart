import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gyeol/data/database/database.dart';
import 'package:gyeol/data/models/app_models.dart';
import 'package:gyeol/data/providers/core_providers.dart';
import 'package:gyeol/data/providers/tasks_provider.dart';

class _ErrorInjectDb extends AppDatabase {
  _ErrorInjectDb(this.controller) : super.forTesting(NativeDatabase.memory());

  final StreamController<List<Task>> controller;

  @override
  Stream<List<Task>> watchTasks({int limit = 100, int offset = 0}) =>
      controller.stream;
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

  group('TasksNotifier', () {
    test('build returns empty list when no tasks', () async {
      final tasks = await container.read(tasksProvider.future);
      expect(tasks, isEmpty);
    });

    test('createTask inserts task and stream updates', () async {
      final notifier = container.read(tasksProvider.notifier);
      final id = await notifier.createTask('process', {
        'input': 'test',
      }, TaskPriority.high);

      expect(id, greaterThan(0));

      await Future<void>.delayed(const Duration(milliseconds: 50));
      final tasks = await container.read(tasksProvider.future);
      expect(tasks, hasLength(1));
      expect(tasks.first.taskType, 'process');
      expect(tasks.first.priority, TaskPriority.high);
      expect(tasks.first.status, TaskStatus.pending);
    });

    test('createTask with medium priority', () async {
      final notifier = container.read(tasksProvider.notifier);
      await notifier.createTask('analyze', null, TaskPriority.medium);

      await Future<void>.delayed(const Duration(milliseconds: 50));
      final tasks = await container.read(tasksProvider.future);
      expect(tasks, hasLength(1));
      expect(tasks.first.priority, TaskPriority.medium);
      expect(tasks.first.taskType, 'analyze');
    });

    test('createTask with low priority', () async {
      final notifier = container.read(tasksProvider.notifier);
      await notifier.createTask('cleanup', [1, 2, 3], TaskPriority.low);

      await Future<void>.delayed(const Duration(milliseconds: 50));
      final tasks = await container.read(tasksProvider.future);
      expect(tasks, hasLength(1));
      expect(tasks.first.priority, TaskPriority.low);
      expect(tasks.first.taskType, 'cleanup');
    });

    test('createTask stores multiple tasks', () async {
      final notifier = container.read(tasksProvider.notifier);
      await notifier.createTask('type-a', null, TaskPriority.low);
      await notifier.createTask('type-b', null, TaskPriority.high);

      await Future<void>.delayed(const Duration(milliseconds: 50));
      final tasks = await container.read(tasksProvider.future);
      expect(tasks, hasLength(2));
      final types = tasks.map((t) => t.taskType).toList();
      expect(types, containsAll(['type-a', 'type-b']));
    });

    test('created task has valid uuid', () async {
      final notifier = container.read(tasksProvider.notifier);
      await notifier.createTask('validate', null, TaskPriority.medium);

      await Future<void>.delayed(const Duration(milliseconds: 50));
      final tasks = await container.read(tasksProvider.future);
      expect(tasks.first.uuid, isNotEmpty);
      expect(tasks.first.uuid.length, greaterThanOrEqualTo(32));
    });

    test('stream error transitions state to AsyncError', () async {
      final controller = StreamController<List<Task>>();
      final errDb = _ErrorInjectDb(controller);
      final errContainer = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(errDb)],
      );

      await errContainer.read(tasksProvider.future);
      controller.addError(StateError('db broken'));
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final state = errContainer.read(tasksProvider);
      expect(state.hasError, isTrue);

      await controller.close();
      errContainer.dispose();
      await errDb.close();
    });
  });
}
