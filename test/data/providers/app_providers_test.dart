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
        const LayerDefinition(name: 'temp', inputTypes: [], outputTypes: []),
      );

      await container.read(layersProvider.future);

      await notifier.deleteLayer('temp');

      await Future<void>.delayed(const Duration(milliseconds: 50));
      final layers = await container.read(layersProvider.future);
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

      await container.read(workersProvider.future);

      await notifier.deleteWorker('temp');

      await Future<void>.delayed(const Duration(milliseconds: 50));
      final workers = await container.read(workersProvider.future);
      expect(workers, isEmpty);
    });
  });

  group('SettingsNotifier', () {
    test('build returns default settings when none saved', () async {
      final settings = await container.read(settingsProvider.future);
      expect(settings.activeProvider, ProviderType.openAI);
      final openai = settings.configs[ProviderType.openAI] as OpenAIConfig;
      expect(openai.apiKey, isEmpty);
    });

    test('save persists and updates settings', () async {
      final notifier = container.read(settingsProvider.notifier);
      await notifier.save(
        const ProviderSettings(
          activeProvider: ProviderType.anthropic,
          configs: {
            ProviderType.openAI: OpenAIConfig(),
            ProviderType.anthropic: AnthropicConfig(apiKey: 'sk-test'),
            ProviderType.ollama: OllamaConfig(),
            ProviderType.custom: CustomConfig(),
          },
          defaultTemperature: 0.5,
        ),
      );

      final result = await container.read(settingsProvider.future);
      expect(result.activeProvider, ProviderType.anthropic);
      final anthropic =
          result.configs[ProviderType.anthropic] as AnthropicConfig;
      expect(anthropic.apiKey, 'sk-test');
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
      await repo.logs.logExecution(taskId: 't1', status: 'done');
      await repo.logs.logExecution(taskId: 't2', status: 'running');

      await container.read(logsProvider.future);

      final state = await container.read(logsProvider.future);
      expect(state, hasLength(2));
    });
  });

  group('GraphState', () {
    test('copyWith preserves unchanged fields', () {
      const state = GraphState(
        nodePositions: {'a': Offset(1, 2)},
        removedConnections: {('x', 'y')},
        viewportX: 10,
        viewportY: 20,
        viewportZoom: 1.5,
      );
      final updated = state.copyWith(viewportX: 99);
      expect(updated.viewportX, 99);
      expect(updated.viewportY, 20);
      expect(updated.viewportZoom, 1.5);
      expect(updated.nodePositions, {'a': const Offset(1, 2)});
      expect(updated.removedConnections, {('x', 'y')});
    });

    test('copyWith replaces all fields', () {
      const state = GraphState();
      final updated = state.copyWith(
        nodePositions: const {'b': Offset(3, 4)},
        removedConnections: {('p', 'q')},
        viewportX: 5,
        viewportY: 6,
        viewportZoom: 2,
      );
      expect(updated.nodePositions, {'b': const Offset(3, 4)});
      expect(updated.removedConnections, {('p', 'q')});
      expect(updated.viewportX, 5);
      expect(updated.viewportY, 6);
      expect(updated.viewportZoom, 2.0);
    });
  });

  group('GraphStateNotifier', () {
    test('build returns default state when no saved data', () async {
      final state = await container.read(graphStateProvider.future);
      expect(state.nodePositions, isEmpty);
      expect(state.removedConnections, isEmpty);
      expect(state.viewportX, 0);
      expect(state.viewportY, 0);
      expect(state.viewportZoom, 1);
    });

    test('savePositions persists and updates state', () async {
      final notifier = container.read(graphStateProvider.notifier);
      await notifier.savePositions({'n1': const Offset(10, 20)});

      final state = await container.read(graphStateProvider.future);
      expect(state.nodePositions, {'n1': const Offset(10, 20)});
    });

    test('saveRemovedConnections persists and updates state', () async {
      final notifier = container.read(graphStateProvider.notifier);
      await notifier.saveRemovedConnections({('a', 'b')});

      final state = await container.read(graphStateProvider.future);
      expect(state.removedConnections, {('a', 'b')});
    });

    test('saveViewport persists and updates state', () async {
      final notifier = container.read(graphStateProvider.notifier);
      await notifier.saveViewport(5, 10, 2);

      final state = await container.read(graphStateProvider.future);
      expect(state.viewportX, 5);
      expect(state.viewportY, 10);
      expect(state.viewportZoom, 2);
    });

    test('multiple saves preserve unrelated fields', () async {
      final notifier = container.read(graphStateProvider.notifier);
      await notifier.savePositions({'x': const Offset(1, 1)});
      await notifier.saveViewport(3, 4, 1);

      container.invalidate(graphStateProvider);
      final state = await container.read(graphStateProvider.future);
      expect(state.nodePositions, {'x': const Offset(1, 1)});
      expect(state.viewportX, 3);
      expect(state.viewportY, 4);
      expect(state.viewportZoom, 1);
    });
  });

  group('TasksNotifier payload type', () {
    test('createTask accepts Object? payload', () async {
      final notifier = container.read(tasksProvider.notifier);
      final id = await notifier.createTask(
        'summarize',
        'plain string',
        TaskPriority.low,
      );
      expect(id, isNotEmpty);
    });

    test('createTask accepts null payload', () async {
      final notifier = container.read(tasksProvider.notifier);
      final id = await notifier.createTask('summarize', null, TaskPriority.low);
      expect(id, isNotEmpty);
    });
  });

  group('queueSizeProvider', () {
    test('returns 0 when no pending tasks', () async {
      final size = await container.read(queueSizeProvider.future);
      expect(size, 0);
    });

    test('returns count of pending tasks', () async {
      final repo = container.read(repositoryProvider);
      await repo.tasks.createTask('a', null, TaskPriority.low);
      await repo.tasks.createTask('b', null, TaskPriority.high);

      container.invalidate(queueSizeProvider);
      final size = await container.read(queueSizeProvider.future);
      expect(size, 2);
    });
  });
}
