import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gyeol/data/models/app_models.dart';
import 'package:gyeol/data/providers/app_providers.dart';
import 'package:gyeol/data/repositories/connection_repository.dart';
import 'package:gyeol/features/layers/pages/layers_page.dart';

List<LayerDefinition> fakeLayers() => [
  const LayerDefinition(
    id: 1,
    name: 'Draft',
    inputTypes: ['issue'],
    outputTypes: ['plan'],
  ),
  const LayerDefinition(
    id: 2,
    name: 'Review',
    inputTypes: ['plan'],
    outputTypes: ['analysis'],
    order: 1,
  ),
];

List<AppTask> fakeTasks() => [
  const AppTask(
    id: 0,
    uuid: 't1',
    taskType: 'generate',
    payload: null,
    priority: TaskPriority.high,
    status: TaskStatus.running,
    layerId: 1,
    workerId: 1,
    createdAt: 1000,
    updatedAt: 1000,
  ),
];

void main() {
  Future<void> pumpLayersPage(
    WidgetTester tester, {
    List<LayerDefinition>? layers,
    List<AppTask>? tasks,
  }) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          layersProvider.overrideWith(
            () => _FakeLayersNotifier(layers ?? fakeLayers()),
          ),
          tasksProvider.overrideWith(
            () => _FakeTasksNotifier(tasks ?? fakeTasks()),
          ),
          workersProvider.overrideWith(() => _FakeWorkersNotifier([])),
          graphStateProvider.overrideWith(_FakeGraphStateNotifier.new),
          connectionsProvider.overrideWith(() => _FakeConnectionsNotifier([])),
        ],
        child: const MaterialApp(home: LayersPage()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<void> disposeLayersPage(WidgetTester tester) async {
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
  }

  group('LayersPage', () {
    testWidgets('renders PageHeader with Layers title', (tester) async {
      await pumpLayersPage(tester);
      expect(find.text('Layers'), findsOneWidget);
      await disposeLayersPage(tester);
    });

    testWidgets('renders description text', (tester) async {
      await pumpLayersPage(tester);
      expect(
        find.text(
          'Graph editor — click nodes to view details, drag to reposition',
        ),
        findsOneWidget,
      );
      await disposeLayersPage(tester);
    });

    testWidgets('renders Add Layer button', (tester) async {
      await pumpLayersPage(tester);
      expect(find.text('Add Layer'), findsWidgets);
      await disposeLayersPage(tester);
    });

    testWidgets('shows empty state when no layers', (tester) async {
      await pumpLayersPage(tester, layers: []);
      expect(find.text('No layers yet'), findsOneWidget);
    });

    testWidgets('shows empty state description when no layers', (tester) async {
      await pumpLayersPage(tester, layers: []);
      expect(
        find.text('Create your first layer to start building the workflow'),
        findsOneWidget,
      );
    });

    testWidgets('shows error on layers provider error', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            layersProvider.overrideWith(_ErrorLayersNotifier.new),
            tasksProvider.overrideWith(() => _FakeTasksNotifier(fakeTasks())),
            workersProvider.overrideWith(() => _FakeWorkersNotifier([])),
            graphStateProvider.overrideWith(_FakeGraphStateNotifier.new),
            connectionsProvider.overrideWith(
              () => _FakeConnectionsNotifier([]),
            ),
          ],
          child: const MaterialApp(home: LayersPage()),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.textContaining('Error:'), findsOneWidget);
    });

    testWidgets('shows loading indicator while loading', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            layersProvider.overrideWith(_LoadingLayersNotifier.new),
            tasksProvider.overrideWith(() => _FakeTasksNotifier(fakeTasks())),
            workersProvider.overrideWith(() => _FakeWorkersNotifier([])),
            graphStateProvider.overrideWith(_FakeGraphStateNotifier.new),
            connectionsProvider.overrideWith(
              () => _FakeConnectionsNotifier([]),
            ),
          ],
          child: const MaterialApp(home: LayersPage()),
        ),
      );
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('renders graph when layers exist', (tester) async {
      await pumpLayersPage(tester);
      expect(find.text('Layers'), findsOneWidget);
      expect(find.text('No layers yet'), findsNothing);
      await disposeLayersPage(tester);
    });

    testWidgets('Add Layer dialog opens with text fields', (tester) async {
      await pumpLayersPage(tester);
      await tester.tap(find.widgetWithText(OutlinedButton, 'Add Layer'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('New Layer'), findsOneWidget);
      expect(find.byType(TextField), findsNWidgets(3));
      await disposeLayersPage(tester);
    });

    testWidgets('Add Layer dialog closes on Cancel', (tester) async {
      await pumpLayersPage(tester);
      await tester.tap(find.widgetWithText(OutlinedButton, 'Add Layer'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('New Layer'), findsNothing);
      await disposeLayersPage(tester);
    });
  });
}

class _FakeLayersNotifier extends LayersNotifier {
  _FakeLayersNotifier(this._layers);
  final List<LayerDefinition> _layers;

  @override
  Future<List<LayerDefinition>> build() async => _layers;
}

class _FakeTasksNotifier extends TasksNotifier {
  _FakeTasksNotifier(this._tasks);
  final List<AppTask> _tasks;

  @override
  Future<List<AppTask>> build() async => _tasks;
}

class _ErrorLayersNotifier extends LayersNotifier {
  @override
  Future<List<LayerDefinition>> build() async => throw Exception('db failed');
}

class _LoadingLayersNotifier extends LayersNotifier {
  @override
  Future<List<LayerDefinition>> build() =>
      Completer<List<LayerDefinition>>().future;
}

class _FakeGraphStateNotifier extends GraphStateNotifier {
  @override
  Future<GraphState> build() async => const GraphState();
}

class _FakeWorkersNotifier extends WorkersNotifier {
  _FakeWorkersNotifier(this._workers);
  final List<WorkerDefinition> _workers;

  @override
  Future<List<WorkerDefinition>> build() async => _workers;
}

class _FakeConnectionsNotifier extends ConnectionsNotifier {
  _FakeConnectionsNotifier(this._connections);
  final List<LayerConnectionData> _connections;

  @override
  Future<List<LayerConnectionData>> build() async => _connections;
}
