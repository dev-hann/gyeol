import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gyeol/data/database/database.dart';
import 'package:gyeol/data/models/app_models.dart';
import 'package:gyeol/data/providers/core_providers.dart';
import 'package:gyeol/data/providers/threads_provider.dart';

class _ErrorInjectDb extends AppDatabase {
  _ErrorInjectDb(this.controller) : super.forTesting(NativeDatabase.memory());

  final StreamController<List<Thread>> controller;

  @override
  Stream<List<Thread>> watchThreads() => controller.stream;
}

void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  group('ThreadsNotifier', () {
    test('build returns empty list when no threads', () async {
      final threads = await container.read(threadsProvider.future);
      expect(threads, isEmpty);
    });

    test('saveThread adds thread and refreshes list', () async {
      final notifier = container.read(threadsProvider.notifier);
      await notifier.saveThread(
        ThreadDefinition(
          id: 0,
          name: 'pipeline-a',
          path: '/src',
          contextPrompt: 'Analyze',
        ),
      );

      await Future<void>.delayed(const Duration(milliseconds: 50));
      final threads = await container.read(threadsProvider.future);
      expect(threads, hasLength(1));
      expect(threads.first.name, 'pipeline-a');
      expect(threads.first.path, '/src');
      expect(threads.first.contextPrompt, 'Analyze');
      expect(threads.first.enabled, isTrue);
      expect(threads.first.status, ThreadStatus.idle);
    });

    test('saveThread updates existing thread with same name', () async {
      final notifier = container.read(threadsProvider.notifier);
      await notifier.saveThread(
        const ThreadDefinition(id: 0, name: 'pipeline-a', path: '/old'),
      );

      await Future<void>.delayed(const Duration(milliseconds: 50));
      await notifier.saveThread(
        const ThreadDefinition(
          id: 0,
          name: 'pipeline-a',
          path: '/new',
          contextPrompt: 'Updated',
        ),
      );

      await Future<void>.delayed(const Duration(milliseconds: 50));
      final threads = await container.read(threadsProvider.future);
      expect(threads, hasLength(1));
      expect(threads.first.path, '/new');
      expect(threads.first.contextPrompt, 'Updated');
    });

    test('saveThread stores multiple threads', () async {
      final notifier = container.read(threadsProvider.notifier);
      await notifier.saveThread(
        const ThreadDefinition(id: 0, name: 't1', path: '/a'),
      );
      await notifier.saveThread(
        const ThreadDefinition(id: 0, name: 't2', path: '/b'),
      );

      await Future<void>.delayed(const Duration(milliseconds: 50));
      final threads = await container.read(threadsProvider.future);
      expect(threads, hasLength(2));
      final names = threads.map((t) => t.name).toList();
      expect(names, containsAll(['t1', 't2']));
    });

    test('deleteThread removes thread and refreshes list', () async {
      final notifier = container.read(threadsProvider.notifier);
      await notifier.saveThread(
        const ThreadDefinition(id: 0, name: 'temp-thread', path: '/tmp'),
      );

      await Future<void>.delayed(const Duration(milliseconds: 50));
      final threads = await container.read(threadsProvider.future);
      expect(threads, hasLength(1));

      await notifier.deleteThread(threads.first.id);

      await Future<void>.delayed(const Duration(milliseconds: 50));
      final updated = await container.read(threadsProvider.future);
      expect(updated, isEmpty);
    });

    test('deleteThread no-op when id does not exist', () async {
      final notifier = container.read(threadsProvider.notifier);
      await notifier.saveThread(
        const ThreadDefinition(id: 0, name: 'keep', path: '/keep'),
      );

      await Future<void>.delayed(const Duration(milliseconds: 50));
      await notifier.deleteThread(9999);

      await Future<void>.delayed(const Duration(milliseconds: 50));
      final threads = await container.read(threadsProvider.future);
      expect(threads, hasLength(1));
      expect(threads.first.name, 'keep');
    });

    test('stream error transitions state to AsyncError', () async {
      final controller = StreamController<List<Thread>>();
      final errDb = _ErrorInjectDb(controller);
      final errContainer = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(errDb)],
      );

      await errContainer.read(threadsProvider.future);
      controller.addError(StateError('db broken'));
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final state = errContainer.read(threadsProvider);
      expect(state.hasError, isTrue);

      await controller.close();
      errContainer.dispose();
      await errDb.close();
    });
  });
}
