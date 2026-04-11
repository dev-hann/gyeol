import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gyeol/data/models/app_models.dart';
import 'package:gyeol/data/providers/app_providers.dart';
import 'package:gyeol/features/dashboard/pages/dashboard_page.dart';

List<LayerDefinition> fakeLayers() => [
  const LayerDefinition(
    id: 1,
    name: 'Draft',
    inputTypes: ['text'],
    outputTypes: ['draft'],
  ),
  const LayerDefinition(
    id: 2,
    name: 'Review',
    inputTypes: ['draft'],
    outputTypes: ['review'],
    order: 1,
  ),
];

List<AppTask> fakeTasks() => [
  AppTask(
    id: 'aaaaaaaa-0000-0000-0000-000000000001',
    taskType: 'Generate',
    payload: null,
    priority: TaskPriority.high,
    status: TaskStatus.pending,
    createdAt: DateTime(2025, 1, 1, 12).millisecondsSinceEpoch,
    updatedAt: DateTime(2025, 1, 1, 12).millisecondsSinceEpoch,
  ),
  AppTask(
    id: 'bbbbbbbb-0000-0000-0000-000000000002',
    taskType: 'Evaluate',
    payload: null,
    priority: TaskPriority.medium,
    status: TaskStatus.running,
    layerId: 1,
    workerName: 'writer-1',
    createdAt: DateTime(2025, 1, 1, 12, 1).millisecondsSinceEpoch,
    updatedAt: DateTime(2025, 1, 1, 12, 1).millisecondsSinceEpoch,
  ),
  AppTask(
    id: 'cccccccc-0000-0000-0000-000000000003',
    taskType: 'Research',
    payload: null,
    priority: TaskPriority.low,
    status: TaskStatus.done,
    createdAt: DateTime(2025, 1, 1, 12, 2).millisecondsSinceEpoch,
    updatedAt: DateTime(2025, 1, 1, 12, 2).millisecondsSinceEpoch,
  ),
  AppTask(
    id: 'dddddddd-0000-0000-0000-000000000004',
    taskType: 'Translate',
    payload: null,
    priority: TaskPriority.high,
    status: TaskStatus.failed,
    createdAt: DateTime(2025, 1, 1, 12, 3).millisecondsSinceEpoch,
    updatedAt: DateTime(2025, 1, 1, 12, 3).millisecondsSinceEpoch,
  ),
];

List<WorkerDefinition> fakeWorkers() => [
  const WorkerDefinition(
    name: 'writer-1',
    layerId: 1,
    systemPrompt: 'You are a writer',
    model: 'gpt-4o',
  ),
  const WorkerDefinition(
    name: 'reviewer-1',
    layerId: 2,
    systemPrompt: 'You are a reviewer',
    model: 'claude-sonnet-4-20250514',
  ),
  const WorkerDefinition(
    name: 'disabled-worker',
    layerId: 2,
    systemPrompt: 'You are disabled',
    model: 'gpt-4o-mini',
    enabled: false,
  ),
];

ProviderSettings fakeSettings() => const ProviderSettings(
  configs: {
    ProviderType.openAI: OpenAIConfig(apiKey: 'sk-test-key'),
    ProviderType.anthropic: AnthropicConfig(),
    ProviderType.ollama: OllamaConfig(baseUrl: 'http://localhost:11434'),
    ProviderType.custom: CustomConfig(),
  },
);

void main() {
  Future<void> pumpDashboard(
    WidgetTester tester, {
    List<AppTask>? tasks,
    List<WorkerDefinition>? workers,
    List<LayerDefinition>? layers,
    ProviderSettings? settings,
    int queueSize = 2,
  }) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tasksProvider.overrideWith(
            () => _FakeTasksNotifier(tasks ?? fakeTasks()),
          ),
          queueSizeProvider.overrideWith((ref) async => queueSize),
          workersProvider.overrideWith(
            () => _FakeWorkersNotifier(workers ?? fakeWorkers()),
          ),
          layersProvider.overrideWith(
            () => _FakeLayersNotifier(layers ?? fakeLayers()),
          ),
          settingsProvider.overrideWith(
            () => _FakeSettingsNotifier(settings ?? fakeSettings()),
          ),
        ],
        child: const MaterialApp(home: DashboardPage()),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('DashboardPage', () {
    testWidgets('renders PageHeader with Dashboard title', (tester) async {
      await pumpDashboard(tester);
      expect(find.text('Dashboard'), findsOneWidget);
    });

    testWidgets('renders PageHeader description', (tester) async {
      await pumpDashboard(tester);
      expect(find.text('Overview of your AI worker system'), findsOneWidget);
    });

    testWidgets('shows stat cards with correct labels', (tester) async {
      await pumpDashboard(tester);
      expect(find.text('QUEUE'), findsOneWidget);
      expect(find.text('PENDING'), findsOneWidget);
      expect(find.text('RUNNING'), findsOneWidget);
      expect(find.text('COMPLETED'), findsOneWidget);
      expect(find.text('FAILED'), findsOneWidget);
    });

    testWidgets('shows correct queue size value', (tester) async {
      await pumpDashboard(tester, queueSize: 5);
      expect(find.text('5'), findsAtLeast(1));
    });

    testWidgets('shows Recent Tasks header', (tester) async {
      await pumpDashboard(tester);
      expect(find.text('Recent Tasks'), findsOneWidget);
    });

    testWidgets('shows total task count', (tester) async {
      await pumpDashboard(tester);
      expect(find.text('4 total'), findsOneWidget);
    });

    testWidgets('renders task type for each task', (tester) async {
      await pumpDashboard(tester);
      expect(find.text('Generate'), findsOneWidget);
      expect(find.text('Evaluate'), findsOneWidget);
      expect(find.text('Research'), findsOneWidget);
      expect(find.text('Translate'), findsOneWidget);
    });

    testWidgets('shows status badges for tasks', (tester) async {
      await pumpDashboard(tester);
      expect(find.text('Pending'), findsOneWidget);
      expect(find.text('Running'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);
      expect(find.text('Failed'), findsOneWidget);
    });

    testWidgets('shows priority badges', (tester) async {
      await pumpDashboard(tester);
      expect(find.text('High'), findsAtLeast(1));
      expect(find.text('Medium'), findsOneWidget);
      expect(find.text('Low'), findsOneWidget);
    });

    testWidgets('shows layer name when present', (tester) async {
      await pumpDashboard(tester);
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Text && w.data != null && w.data!.contains('Layer: Draft'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('shows worker name when present', (tester) async {
      await pumpDashboard(tester);
      expect(
        find.byWidgetPredicate((w) => w is Text && w.data == 'writer-1'),
        findsAtLeast(1),
      );
    });

    testWidgets('shows truncated task id', (tester) async {
      await pumpDashboard(tester);
      expect(find.text('aaaaaaaa'), findsOneWidget);
    });

    testWidgets('shows empty message when no tasks', (tester) async {
      await pumpDashboard(tester, tasks: []);
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Text && w.data != null && w.data!.contains('No tasks yet'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('shows error message on provider error', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tasksProvider.overrideWith(_ErrorTasksNotifier.new),
            queueSizeProvider.overrideWith((ref) async => 0),
            workersProvider.overrideWith(
              () => _FakeWorkersNotifier(fakeWorkers()),
            ),
            layersProvider.overrideWith(
              () => _FakeLayersNotifier(fakeLayers()),
            ),
            settingsProvider.overrideWith(
              () => _FakeSettingsNotifier(fakeSettings()),
            ),
          ],
          child: const MaterialApp(home: DashboardPage()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Error:'), findsOneWidget);
    });
  });

  group('DashboardPage Workers section', () {
    testWidgets('shows Workers section header', (tester) async {
      await pumpDashboard(tester);
      expect(find.text('Workers'), findsOneWidget);
    });

    testWidgets('shows total workers count', (tester) async {
      await pumpDashboard(tester);
      expect(find.text('3 total'), findsOneWidget);
    });

    testWidgets('shows worker names as chips', (tester) async {
      await pumpDashboard(tester);
      expect(find.text('writer-1'), findsAtLeast(1));
      expect(find.text('reviewer-1'), findsOneWidget);
      expect(find.text('disabled-worker'), findsOneWidget);
    });

    testWidgets('shows worker models', (tester) async {
      await pumpDashboard(tester);
      expect(find.text('gpt-4o'), findsOneWidget);
      expect(find.text('claude-sonnet-4-20250514'), findsOneWidget);
      expect(find.text('gpt-4o-mini'), findsOneWidget);
    });

    testWidgets('shows worker enabled/disabled status', (tester) async {
      await pumpDashboard(tester);
      expect(find.text('Enabled'), findsAtLeast(1));
      expect(find.text('Disabled'), findsOneWidget);
    });

    testWidgets('shows layer grouping for workers', (tester) async {
      await pumpDashboard(tester);
      expect(find.text('Draft'), findsAtLeast(1));
      expect(find.text('Review'), findsAtLeast(1));
    });

    testWidgets('shows no workers message when empty', (tester) async {
      await pumpDashboard(tester, workers: []);
      expect(find.text('No workers configured'), findsOneWidget);
    });
  });

  group('DashboardPage Provider status section', () {
    testWidgets('shows Providers section header', (tester) async {
      await pumpDashboard(tester);
      expect(find.text('Providers'), findsOneWidget);
    });

    testWidgets('shows provider type names', (tester) async {
      await pumpDashboard(tester);
      expect(find.text('OpenAI'), findsOneWidget);
      expect(find.text('Anthropic'), findsOneWidget);
      expect(find.text('Ollama'), findsOneWidget);
      expect(find.text('Custom'), findsOneWidget);
    });

    testWidgets('shows configured provider indicator', (tester) async {
      await pumpDashboard(tester);
      expect(find.text('Active'), findsOneWidget);
    });

    testWidgets('shows all providers as unconfigured when defaults', (
      tester,
    ) async {
      await pumpDashboard(tester, settings: const ProviderSettings());
      expect(find.text('Not configured'), findsAtLeast(1));
    });
  });
}

class _FakeTasksNotifier extends TasksNotifier {
  _FakeTasksNotifier(this._tasks);
  final List<AppTask> _tasks;

  @override
  Future<List<AppTask>> build() async => _tasks;
}

class _FakeWorkersNotifier extends WorkersNotifier {
  _FakeWorkersNotifier(this._workers);
  final List<WorkerDefinition> _workers;

  @override
  Future<List<WorkerDefinition>> build() async => _workers;
}

class _FakeLayersNotifier extends LayersNotifier {
  _FakeLayersNotifier(this._layers);
  final List<LayerDefinition> _layers;

  @override
  Future<List<LayerDefinition>> build() async => _layers;
}

class _FakeSettingsNotifier extends SettingsNotifier {
  _FakeSettingsNotifier(this._settings);
  final ProviderSettings _settings;

  @override
  Future<ProviderSettings> build() async => _settings;
}

class _ErrorTasksNotifier extends TasksNotifier {
  @override
  Future<List<AppTask>> build() async => throw Exception('db failed');
}
