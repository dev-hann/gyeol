import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gyeol/data/models/app_models.dart';
import 'package:gyeol/data/providers/app_providers.dart';
import 'package:gyeol/data/repositories/connection_repository.dart';
import 'package:gyeol/features/threads/pages/thread_detail_page.dart';

const _threadId = 1;

const _fakeThread = ThreadDefinition(
  id: _threadId,
  name: 'my-thread',
  path: '/home/user/project',
);

final _fakeLayers = [
  const LayerDefinition(
    id: 1,
    threadId: _threadId,
    name: 'Draft',
    inputTypes: ['text'],
    outputTypes: ['draft'],
  ),
  const LayerDefinition(
    id: 2,
    threadId: _threadId,
    name: 'Review',
    inputTypes: ['draft'],
    outputTypes: ['review'],
  ),
];

final _fakeTasks = [
  const AppTask(
    id: 0,
    uuid: 't1',
    taskType: 'generate',
    payload: null,
    priority: TaskPriority.high,
    status: TaskStatus.running,
    layerId: 1,
    createdAt: 1000,
    updatedAt: 1000,
  ),
];

const _fakeConnections = [
  LayerConnectionData(sourceLayerId: 1, targetLayerId: 2),
];

Future<void> pumpThreadDetailPage(
  WidgetTester tester, {
  List<LayerDefinition>? layers,
  List<ThreadDefinition>? threads,
  List<AppTask>? tasks,
  List<LayerConnectionData>? connections,
  bool layersError = false,
}) async {
  tester.view.physicalSize = const Size(1200, 900);
  tester.view.devicePixelRatio = 1.0;
  final effectiveThreads = threads ?? [_fakeThread];
  final effectiveLayers = layers ?? _fakeLayers;
  final effectiveTasks = tasks ?? _fakeTasks;
  final effectiveConnections = connections ?? _fakeConnections;

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        threadsProvider.overrideWith(
          () => _FakeThreadsNotifier(threads: effectiveThreads),
        ),
        threadLayersProvider(_threadId).overrideWith(
          (ref) => layersError
              ? Stream.error(Exception('db failed'))
              : Stream.value(effectiveLayers),
        ),
        tasksProvider.overrideWith(
          () => _FakeTasksNotifier(tasks: effectiveTasks),
        ),
        graphStateProvider.overrideWith(_FakeGraphStateNotifier.new),
        connectionsProvider.overrideWith(
          () => _FakeConnectionsNotifier(connections: effectiveConnections),
        ),
        workersProvider.overrideWith(() => _FakeWorkersNotifier(workers: [])),
      ],
      child: MaterialApp(
        home: ThreadDetailPage(threadId: _threadId, onBack: () {}),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  group('ThreadDetailPage header', () {
    testWidgets('renders thread name', (tester) async {
      await pumpThreadDetailPage(tester);
      expect(find.text('my-thread'), findsOneWidget);
    });

    testWidgets('renders thread path', (tester) async {
      await pumpThreadDetailPage(tester);
      expect(find.text('/home/user/project'), findsOneWidget);
    });

    testWidgets('renders fallback name when thread not found', (tester) async {
      await pumpThreadDetailPage(tester, threads: []);
      expect(find.text('Thread $_threadId'), findsOneWidget);
    });

    testWidgets('renders back button', (tester) async {
      await pumpThreadDetailPage(tester);
      expect(find.byTooltip('Back'), findsOneWidget);
    });

    testWidgets('renders Auto Arrange button', (tester) async {
      await pumpThreadDetailPage(tester);
      expect(find.byTooltip('Auto Arrange'), findsOneWidget);
    });

    testWidgets('renders Add Layer button', (tester) async {
      await pumpThreadDetailPage(tester);
      expect(find.text('Add Layer'), findsOneWidget);
    });
  });

  group('ThreadDetailPage empty state', () {
    testWidgets('shows empty state when no layers', (tester) async {
      await pumpThreadDetailPage(tester, layers: []);
      expect(find.text('No layers yet'), findsOneWidget);
      expect(
        find.text('Create your first layer to start building the workflow'),
        findsOneWidget,
      );
    });

    testWidgets('shows Add Layer in empty state', (tester) async {
      await pumpThreadDetailPage(tester, layers: []);
      expect(find.text('Add Layer'), findsNWidgets(2));
    });
  });

  group('ThreadDetailPage graph', () {
    testWidgets('does not show empty state when layers exist', (tester) async {
      await pumpThreadDetailPage(tester);
      expect(find.text('No layers yet'), findsNothing);
    });

    testWidgets('shows error when layers stream errors', (tester) async {
      await pumpThreadDetailPage(tester, layersError: true);
      expect(find.textContaining('Error:'), findsOneWidget);
    });
  });

  group('ThreadDetailPage Add Layer dialog', () {
    testWidgets('opens dialog on Add Layer tap', (tester) async {
      await pumpThreadDetailPage(tester, layers: []);
      await tester.tap(find.text('Add Layer').first);
      await tester.pumpAndSettle();
      expect(find.text('New Layer'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Create'), findsOneWidget);
    });

    testWidgets('dialog contains Name field', (tester) async {
      await pumpThreadDetailPage(tester, layers: []);
      await tester.tap(find.text('Add Layer').first);
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsNWidgets(3));
    });

    testWidgets('closes dialog on Cancel tap', (tester) async {
      await pumpThreadDetailPage(tester, layers: []);
      await tester.tap(find.text('Add Layer').first);
      await tester.pumpAndSettle();
      expect(find.text('New Layer'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('New Layer'), findsNothing);
    });
  });
}

class _FakeThreadsNotifier extends ThreadsNotifier {
  _FakeThreadsNotifier({required this.threads});
  final List<ThreadDefinition> threads;

  @override
  Future<List<ThreadDefinition>> build() async => threads;
}

class _FakeTasksNotifier extends TasksNotifier {
  _FakeTasksNotifier({required this.tasks});
  final List<AppTask> tasks;

  @override
  Future<List<AppTask>> build() async => tasks;
}

class _FakeGraphStateNotifier extends GraphStateNotifier {
  @override
  Future<GraphState> build() async => const GraphState();
}

class _FakeConnectionsNotifier extends ConnectionsNotifier {
  _FakeConnectionsNotifier({required this.connections});
  final List<LayerConnectionData> connections;

  @override
  Future<List<LayerConnectionData>> build() async => connections;
}

class _FakeWorkersNotifier extends WorkersNotifier {
  _FakeWorkersNotifier({required this.workers});
  final List<WorkerDefinition> workers;

  @override
  Future<List<WorkerDefinition>> build() async => workers;
}
