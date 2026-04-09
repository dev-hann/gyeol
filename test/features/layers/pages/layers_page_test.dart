import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gyeol/data/models/app_models.dart';
import 'package:gyeol/data/providers/app_providers.dart';
import 'package:gyeol/features/layers/pages/layers_page.dart';

List<LayerDefinition> fakeLayers() => [
  LayerDefinition(
    name: 'Draft',
    inputTypes: ['issue'],
    outputTypes: ['plan'],
    workerNames: ['writer-1'],
    order: 0,
  ),
  LayerDefinition(
    name: 'Review',
    inputTypes: ['plan'],
    outputTypes: ['analysis'],
    workerNames: ['reviewer-1'],
    order: 1,
  ),
];

List<AppTask> fakeTasks() => [
  AppTask(
    id: 't1',
    taskType: 'generate',
    payload: null,
    priority: TaskPriority.high,
    status: TaskStatus.running,
    layerName: 'Draft',
    workerName: 'writer-1',
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
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          layersProvider.overrideWith(
            () => _FakeLayersNotifier(layers ?? fakeLayers()),
          ),
          tasksProvider.overrideWith(
            () => _FakeTasksNotifier(tasks ?? fakeTasks()),
          ),
        ],
        child: const MaterialApp(home: LayersPage()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  group('LayersPage', () {
    testWidgets('renders PageHeader with Layers title', (tester) async {
      await pumpLayersPage(tester);
      expect(find.text('Layers'), findsOneWidget);
    });

    testWidgets('renders description text', (tester) async {
      await pumpLayersPage(tester);
      expect(
        find.text(
          'Graph editor — click nodes to view details, drag to reposition',
        ),
        findsOneWidget,
      );
    });

    testWidgets('renders Add Layer button', (tester) async {
      await pumpLayersPage(tester);
      expect(find.text('Add Layer'), findsWidgets);
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
            layersProvider.overrideWith(() => _ErrorLayersNotifier()),
            tasksProvider.overrideWith(() => _FakeTasksNotifier(fakeTasks())),
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
            layersProvider.overrideWith(() => _LoadingLayersNotifier()),
            tasksProvider.overrideWith(() => _FakeTasksNotifier(fakeTasks())),
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
    });
  });
}

class _FakeLayersNotifier extends LayersNotifier {
  final List<LayerDefinition> _layers;
  _FakeLayersNotifier(this._layers);

  @override
  Future<List<LayerDefinition>> build() async => _layers;
}

class _FakeTasksNotifier extends TasksNotifier {
  final List<AppTask> _tasks;
  _FakeTasksNotifier(this._tasks);

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
