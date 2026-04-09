import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gyeol/data/database/database.dart';
import 'package:gyeol/data/models/app_models.dart';
import 'package:gyeol/data/providers/app_providers.dart';

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

    test('createTask stores task and refreshes list', () async {
      final notifier = container.read(tasksProvider.notifier);
      final id = await notifier.createTask('summarize', {
        'text': 'hello',
      }, TaskPriority.medium);
      expect(id, isNotEmpty);

      final tasks = await container.read(tasksProvider.future);
      expect(tasks, hasLength(1));
      expect(tasks.first.taskType, 'summarize');
      expect(tasks.first.priority, TaskPriority.medium);
    });
  });

  group('LayersNotifier', () {
    test('build returns empty list when no layers', () async {
      final layers = await container.read(layersProvider.future);
      expect(layers, isEmpty);
    });

    test('saveLayer adds layer and refreshes list', () async {
      final notifier = container.read(layersProvider.notifier);
      await notifier.saveLayer(
        const LayerDefinition(
          name: 'parse',
          inputTypes: ['text'],
          outputTypes: ['analysis'],
          workerNames: ['w1'],
          order: 1,
        ),
      );

      final layers = await container.read(layersProvider.future);
      expect(layers, hasLength(1));
      expect(layers.first.name, 'parse');
      expect(layers.first.inputTypes, ['text']);
    });

    test('deleteLayer removes layer and refreshes list', () async {
      final notifier = container.read(layersProvider.notifier);
      await notifier.saveLayer(
        const LayerDefinition(
          name: 'temp',
          inputTypes: [],
          outputTypes: [],
          workerNames: [],
        ),
      );

      var layers = await container.read(layersProvider.future);
      expect(layers, hasLength(1));

      await notifier.deleteLayer('temp');
      layers = await container.read(layersProvider.future);
      expect(layers, isEmpty);
    });
  });

  group('WorkersNotifier', () {
    test('build returns empty list when no workers', () async {
      final workers = await container.read(workersProvider.future);
      expect(workers, isEmpty);
    });

    test('saveWorker adds worker and refreshes list', () async {
      final notifier = container.read(workersProvider.notifier);
      await notifier.saveWorker(
        const WorkerDefinition(
          name: 'parser',
          layerName: 'parse',
          systemPrompt: 'Parse the text',
        ),
      );

      final workers = await container.read(workersProvider.future);
      expect(workers, hasLength(1));
      expect(workers.first.name, 'parser');
      expect(workers.first.layerName, 'parse');
    });

    test('deleteWorker removes worker and refreshes list', () async {
      final notifier = container.read(workersProvider.notifier);
      await notifier.saveWorker(
        const WorkerDefinition(
          name: 'temp',
          layerName: 'tmp',
          systemPrompt: 'tmp',
        ),
      );

      await notifier.deleteWorker('temp');
      final workers = await container.read(workersProvider.future);
      expect(workers, isEmpty);
    });
  });

  group('SettingsNotifier', () {
    test('build returns default settings when none saved', () async {
      final settings = await container.read(settingsProvider.future);
      expect(settings.provider, ProviderType.openAI);
      expect(settings.openaiApiKey, isEmpty);
    });

    test('save persists and updates settings', () async {
      final notifier = container.read(settingsProvider.notifier);
      await notifier.save(
        const ProviderSettings(
          provider: ProviderType.anthropic,
          anthropicApiKey: 'sk-test',
          defaultTemperature: 0.5,
        ),
      );

      final result = await container.read(settingsProvider.future);
      expect(result.provider, ProviderType.anthropic);
      expect(result.anthropicApiKey, 'sk-test');
      expect(result.defaultTemperature, 0.5);
    });
  });

  group('LogsNotifier', () {
    test('build returns empty list when no logs', () async {
      final logs = await container.read(logsProvider.future);
      expect(logs, isEmpty);
    });

    test('refresh with taskId filters logs', () async {
      final repo = container.read(repositoryProvider);
      await repo.logExecution(taskId: 't1', status: 'done');
      await repo.logExecution(taskId: 't2', status: 'running');

      final notifier = container.read(logsProvider.notifier);
      await notifier.refresh(taskId: 't1');

      final state = await container.read(logsProvider.future);
      expect(state, hasLength(1));
      expect(state.first.taskId, 't1');
    });
  });

  group('queueSizeProvider', () {
    test('returns 0 when no pending tasks', () async {
      final size = await container.read(queueSizeProvider.future);
      expect(size, 0);
    });

    test('returns count of pending tasks', () async {
      final repo = container.read(repositoryProvider);
      await repo.createTask('a', null, TaskPriority.low);
      await repo.createTask('b', null, TaskPriority.high);

      container.invalidate(queueSizeProvider);
      final size = await container.read(queueSizeProvider.future);
      expect(size, 2);
    });
  });
}
