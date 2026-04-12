import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gyeol/data/database/database.dart';
import 'package:gyeol/data/providers/core_providers.dart';
import 'package:gyeol/data/repositories/app_repository.dart';
import 'package:gyeol/engine/scheduler.dart';

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

  group('databaseProvider', () {
    test('returns AppDatabase instance when overridden', () {
      final result = container.read(databaseProvider);
      expect(result, isA<AppDatabase>());
      expect(result, same(db));
    });
  });

  group('repositoryProvider', () {
    test('returns AppRepository instance', () {
      final repo = container.read(repositoryProvider);
      expect(repo, isA<AppRepository>());
    });

    test('watches databaseProvider dependency', () {
      final repo = container.read(repositoryProvider);
      expect(repo, isNotNull);
    });

    test('provides access to sub-repositories', () {
      final repo = container.read(repositoryProvider);
      expect(repo.tasks, isNotNull);
      expect(repo.layers, isNotNull);
      expect(repo.workers, isNotNull);
    });
  });

  group('schedulerProvider', () {
    test('returns Scheduler instance', () {
      final scheduler = container.read(schedulerProvider);
      expect(scheduler, isA<Scheduler>());
    });

    test('has default maxConcurrent of 4', () {
      final scheduler = container.read(schedulerProvider);
      expect(scheduler.maxConcurrent, 4);
    });

    test('watches repositoryProvider dependency', () {
      final scheduler = container.read(schedulerProvider);
      expect(scheduler, isNotNull);
    });
  });

  group('dependency chain', () {
    test('database override propagates through full chain', () {
      final database = container.read(databaseProvider);
      final repo = container.read(repositoryProvider);
      final scheduler = container.read(schedulerProvider);

      expect(database, same(db));
      expect(repo, isA<AppRepository>());
      expect(scheduler, isA<Scheduler>());
    });

    test('each provider resolves to a unique instance per container', () {
      final repo1 = container.read(repositoryProvider);
      final repo2 = container.read(repositoryProvider);
      expect(identical(repo1, repo2), isTrue);
    });
  });
}
