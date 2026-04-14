import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gyeol/data/models/app_models.dart';
import 'package:gyeol/data/providers/app_providers.dart';
import 'package:gyeol/features/layers/graph/graph_utils.dart';
import 'package:gyeol/features/layers/graph/node_detail_panel.dart';
import 'package:vyuh_node_flow/vyuh_node_flow.dart';

List<LayerDefinition> fakeLayers() => [
  const LayerDefinition(
    id: 1,
    threadId: 1,
    name: 'Draft',
    inputTypes: ['text', 'prompt'],
    outputTypes: ['draft'],
  ),
  const LayerDefinition(
    id: 2,
    threadId: 1,
    name: 'Review',
    inputTypes: ['draft'],
    outputTypes: ['review'],
    order: 1,
    enabled: false,
  ),
];

List<WorkerDefinition> fakeWorkers() => [
  const WorkerDefinition(
    id: 1,
    name: 'writer-1',
    layerId: 1,
    systemPrompt: 'You are a creative writer producing excellent prose.',
    model: 'gpt-4o',
    temperature: 0.7,
    maxTokens: 4096,
  ),
  const WorkerDefinition(
    id: 2,
    name: 'critic-1',
    layerId: 2,
    systemPrompt: 'Short prompt.',
    enabled: false,
  ),
];

NodeFlowController<LayerGraphData, void> createTestController() {
  final nodes = buildNodes(fakeLayers(), [], fakeWorkers(), []);
  return NodeFlowController<LayerGraphData, void>(nodes: nodes);
}

Future<void> pumpPanel(
  WidgetTester tester, {
  int? layerId,
  List<LayerDefinition>? layers,
  List<WorkerDefinition>? workers,
  VoidCallback? onClose,
  NodeFlowController<LayerGraphData, void>? controller,
}) async {
  final ctrl = controller ?? createTestController();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        layersProvider.overrideWith(
          () => _FakeLayersNotifier(layers ?? fakeLayers()),
        ),
        workersProvider.overrideWith(
          () => _FakeWorkersNotifier(workers ?? fakeWorkers()),
        ),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: NodeDetailPanel(
            layerId: layerId,
            onClose: onClose ?? () {},
            controller: ctrl,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('NodeDetailPanel — null layerId', () {
    testWidgets('renders SizedBox.shrink when layerId is null', (tester) async {
      await pumpPanel(tester);
      expect(find.byType(SizedBox), findsWidgets);
      expect(find.text('Draft'), findsNothing);
    });
  });

  group('NodeDetailPanel — layer not found', () {
    testWidgets('renders SizedBox.shrink when layer not in list', (
      tester,
    ) async {
      await pumpPanel(tester, layerId: 999);
      expect(find.text('Missing'), findsNothing);
    });
  });

  group('NodeDetailPanel — view mode', () {
    testWidgets('renders layer name in header', (tester) async {
      await pumpPanel(tester, layerId: 1);
      expect(find.text('Draft'), findsOneWidget);
    });

    testWidgets('renders input type tags', (tester) async {
      await pumpPanel(tester, layerId: 1);
      expect(find.text('text'), findsOneWidget);
      expect(find.text('prompt'), findsOneWidget);
    });

    testWidgets('renders output type tags', (tester) async {
      await pumpPanel(tester, layerId: 1);
      expect(find.text('draft'), findsOneWidget);
    });

    testWidgets('renders Active badge for enabled layer', (tester) async {
      await pumpPanel(tester, layerId: 1);
      expect(find.text('Active'), findsOneWidget);
    });

    testWidgets('renders Disabled badge for disabled layer', (tester) async {
      await pumpPanel(tester, layerId: 2);
      expect(find.text('Disabled'), findsOneWidget);
    });

    testWidgets('renders Edit button', (tester) async {
      await pumpPanel(tester, layerId: 1);
      expect(find.text('Edit'), findsOneWidget);
    });

    testWidgets('renders delete icon button for layer', (tester) async {
      await pumpPanel(tester, layerId: 1);
      expect(find.byIcon(Icons.delete_outline), findsWidgets);
    });

    testWidgets('renders close button', (tester) async {
      await pumpPanel(tester, layerId: 1);
      final closeButtons = find.byIcon(Icons.close);
      expect(closeButtons, findsWidgets);
      expect(
        find.byWidgetPredicate(
          (w) => w is Icon && w.icon == Icons.close && w.size == 18.0,
        ),
        findsOneWidget,
      );
    });

    testWidgets('onClose callback is invoked on close tap', (tester) async {
      var closed = false;
      await pumpPanel(tester, layerId: 1, onClose: () => closed = true);
      await tester.tap(
        find.byWidgetPredicate(
          (w) => w is Icon && w.icon == Icons.close && w.size == 18.0,
        ),
      );
      expect(closed, isTrue);
    });

    testWidgets('renders worker count header', (tester) async {
      await pumpPanel(tester, layerId: 1);
      expect(find.text('Workers (1)'), findsOneWidget);
    });

    testWidgets('renders worker names', (tester) async {
      await pumpPanel(tester, layerId: 1);
      expect(find.text('writer-1'), findsOneWidget);
    });

    testWidgets('renders worker model badge', (tester) async {
      await pumpPanel(tester, layerId: 1);
      expect(find.text('gpt-4o'), findsOneWidget);
    });

    testWidgets('renders Add worker button', (tester) async {
      await pumpPanel(tester, layerId: 1);
      expect(find.text('Add'), findsOneWidget);
    });
  });

  group('NodeDetailPanel — edit mode', () {
    testWidgets('tapping Edit shows edit form fields', (tester) async {
      await pumpPanel(tester, layerId: 1);
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      expect(find.text('Input Types (comma-separated)'), findsOneWidget);
      expect(find.text('Output Types (comma-separated)'), findsOneWidget);
      expect(find.text('Order'), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets('tapping Cancel returns to view mode', (tester) async {
      await pumpPanel(tester, layerId: 1);
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Edit'), findsOneWidget);
      expect(find.text('Input Types (comma-separated)'), findsNothing);
    });
  });

  group('NodeDetailPanel — worker form', () {
    testWidgets('tapping Add shows New Worker form', (tester) async {
      await pumpPanel(tester, layerId: 1);
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();
      expect(find.text('New Worker'), findsOneWidget);
    });

    testWidgets('cancel hides worker form', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      await pumpPanel(tester, layerId: 1);
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();
      expect(find.text('New Worker'), findsOneWidget);
      await tester.dragUntilVisible(
        find.text('Cancel').last,
        find.byType(ListView),
        const Offset(0, -50),
      );
      await tester.tap(find.text('Cancel').last);
      await tester.pumpAndSettle();
      expect(find.text('New Worker'), findsNothing);
    });
  });

  group('NodeDetailPanel — loading state', () {
    testWidgets('shows CircularProgressIndicator while loading', (
      tester,
    ) async {
      final ctrl = NodeFlowController<LayerGraphData, void>();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            layersProvider.overrideWith(_NeverLayersNotifier.new),
            workersProvider.overrideWith(
              () => _FakeWorkersNotifier(fakeWorkers()),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: NodeDetailPanel(
                layerId: 1,
                onClose: () {},
                controller: ctrl,
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });

  group('NodeDetailPanel — didUpdateWidget syncs controllers', () {
    testWidgets('updates input types text when layerId changes', (
      tester,
    ) async {
      final layers = [
        const LayerDefinition(
          id: 1,
          threadId: 1,
          name: 'A',
          inputTypes: ['alpha'],
          outputTypes: ['a-out'],
        ),
        const LayerDefinition(
          id: 2,
          threadId: 1,
          name: 'B',
          inputTypes: ['beta'],
          outputTypes: ['b-out'],
        ),
      ];
      final ctrl = NodeFlowController<LayerGraphData, void>(
        nodes: buildNodes(layers, [], [], []),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            layersProvider.overrideWith(() => _FakeLayersNotifier(layers)),
            workersProvider.overrideWith(() => _FakeWorkersNotifier([])),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: NodeDetailPanel(
                layerId: 1,
                onClose: () {},
                controller: ctrl,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('alpha'), findsOneWidget);
      expect(find.text('beta'), findsNothing);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            layersProvider.overrideWith(() => _FakeLayersNotifier(layers)),
            workersProvider.overrideWith(() => _FakeWorkersNotifier([])),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: NodeDetailPanel(
                layerId: 2,
                onClose: () {},
                controller: ctrl,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('beta'), findsOneWidget);
      expect(find.text('alpha'), findsNothing);
    });

    testWidgets('updates enabled status when switching layers', (tester) async {
      final layers = [
        const LayerDefinition(
          id: 1,
          threadId: 1,
          name: 'On',
          inputTypes: ['x'],
          outputTypes: [],
        ),
        const LayerDefinition(
          id: 2,
          threadId: 1,
          name: 'Off',
          inputTypes: ['x'],
          outputTypes: [],
          enabled: false,
        ),
      ];
      final ctrl = NodeFlowController<LayerGraphData, void>(
        nodes: buildNodes(layers, [], [], []),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            layersProvider.overrideWith(() => _FakeLayersNotifier(layers)),
            workersProvider.overrideWith(() => _FakeWorkersNotifier([])),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: NodeDetailPanel(
                layerId: 1,
                onClose: () {},
                controller: ctrl,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Active'), findsOneWidget);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            layersProvider.overrideWith(() => _FakeLayersNotifier(layers)),
            workersProvider.overrideWith(() => _FakeWorkersNotifier([])),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: NodeDetailPanel(
                layerId: 2,
                onClose: () {},
                controller: ctrl,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Disabled'), findsOneWidget);
    });
  });

  group('NodeDetailPanel — empty types', () {
    testWidgets('shows None for empty input types', (tester) async {
      await pumpPanel(
        tester,
        layerId: 1,
        layers: [
          const LayerDefinition(
            id: 1,
            threadId: 1,
            name: 'Empty',
            inputTypes: [],
            outputTypes: ['out'],
          ),
        ],
        workers: [],
      );
      expect(find.text('None'), findsOneWidget);
    });
  });
}

class _FakeLayersNotifier extends LayersNotifier {
  _FakeLayersNotifier(this._layers);
  final List<LayerDefinition> _layers;

  @override
  Future<List<LayerDefinition>> build() async => _layers;
}

class _FakeWorkersNotifier extends WorkersNotifier {
  _FakeWorkersNotifier(this._workers);
  final List<WorkerDefinition> _workers;

  @override
  Future<List<WorkerDefinition>> build() async => _workers;
}

class _NeverLayersNotifier extends LayersNotifier {
  @override
  Future<List<LayerDefinition>> build() =>
      NeverCompleter<List<LayerDefinition>>().future;
}

class NeverCompleter<T> {
  final Completer<T> _completer = Completer<T>();
  Future<T> get future => _completer.future;
}
