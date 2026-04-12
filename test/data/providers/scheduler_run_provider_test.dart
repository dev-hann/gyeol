import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gyeol/data/database/database.dart';
import 'package:gyeol/data/models/app_models.dart';
import 'package:gyeol/data/providers/core_providers.dart';
import 'package:gyeol/data/providers/scheduler_run_provider.dart';

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

  group('queueSizeProvider', () {
    test('returns 0 when no pending tasks', () async {
      final size = await container.read(queueSizeProvider.future);
      expect(size, 0);
    });

    test('returns count after inserting pending tasks', () async {
      final repo = container.read(repositoryProvider);
      await repo.tasks.createTask('test', null, TaskPriority.medium);
      await repo.tasks.createTask('test2', null, TaskPriority.high);

      container.invalidate(queueSizeProvider);
      final size = await container.read(queueSizeProvider.future);
      expect(size, 2);
    });
  });

  group('runSchedulerProvider', () {
    test('returns empty list when queue is empty', () async {
      final results = await container.read(runSchedulerProvider(null).future);
      expect(results, isEmpty);
    });

    test('runSchedulerProvider returns empty for no matching layers', () async {
      final repo = container.read(repositoryProvider);
      await repo.tasks.createTask('test', null, TaskPriority.medium);

      final results = await container.read(runSchedulerProvider(null).future);
      expect(results, isEmpty);
    });
  });
}
