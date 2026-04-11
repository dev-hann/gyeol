import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gyeol/data/models/app_models.dart';
import 'package:gyeol/data/providers/app_providers.dart';
import 'package:gyeol/features/workers/pages/workers_page.dart';

List<WorkerDefinition> fakeWorkers() => [
  const WorkerDefinition(
    name: 'writer-1',
    layerName: 'Draft',
    systemPrompt: 'You are a creative writer.',
    model: 'gpt-4o',
    temperature: 0.7,
    maxTokens: 4096,
  ),
  const WorkerDefinition(
    name: 'critic-1',
    layerName: 'Draft',
    systemPrompt: 'You are a critical reviewer.',
  ),
  const WorkerDefinition(
    name: 'orphan-1',
    layerName: 'NonExistent',
    systemPrompt: 'I have no layer.',
    enabled: false,
  ),
];

List<LayerDefinition> fakeLayers() => [
  const LayerDefinition(
    name: 'Draft',
    inputTypes: ['text'],
    outputTypes: ['draft'],
  ),
];

void main() {
  Future<void> pumpWorkersPage(
    WidgetTester tester, {
    List<WorkerDefinition>? workers,
    List<LayerDefinition>? layers,
  }) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          workersProvider.overrideWith(
            () => _FakeWorkersNotifier(workers ?? fakeWorkers()),
          ),
          layersProvider.overrideWith(
            () => _FakeLayersNotifier(layers ?? fakeLayers()),
          ),
        ],
        child: const MaterialApp(home: WorkersPage()),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('WorkersPage', () {
    testWidgets('renders PageHeader with Workers title', (tester) async {
      await pumpWorkersPage(tester);
      expect(find.text('Workers'), findsOneWidget);
    });

    testWidgets('renders description', (tester) async {
      await pumpWorkersPage(tester);
      expect(
        find.text('Overview of all workers across layers'),
        findsOneWidget,
      );
    });

    testWidgets('shows info banner text', (tester) async {
      await pumpWorkersPage(tester);
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Text &&
              w.data != null &&
              w.data!.contains('managed through layers'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('shows layer group name', (tester) async {
      await pumpWorkersPage(tester);
      expect(find.text('Draft'), findsOneWidget);
    });

    testWidgets('shows worker count badge per layer', (tester) async {
      await pumpWorkersPage(tester);
      expect(find.text('2 workers'), findsOneWidget);
    });

    testWidgets('shows worker names', (tester) async {
      await pumpWorkersPage(tester);
      expect(find.text('writer-1'), findsOneWidget);
      expect(find.text('critic-1'), findsOneWidget);
    });

    testWidgets('shows worker model badge when present', (tester) async {
      await pumpWorkersPage(tester);
      expect(find.text('gpt-4o'), findsOneWidget);
    });

    testWidgets('shows Active and Disabled badges', (tester) async {
      await pumpWorkersPage(tester);
      expect(find.text('Active'), findsWidgets);
      expect(find.text('Disabled'), findsOneWidget);
    });

    testWidgets('shows temperature and maxTokens for worker', (tester) async {
      await pumpWorkersPage(tester);
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Text &&
              w.data != null &&
              w.data!.contains('T:0.7') &&
              w.data!.contains('M:4096'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('shows unassigned group for orphan workers', (tester) async {
      await pumpWorkersPage(tester);
      expect(find.text('Unassigned'), findsOneWidget);
    });

    testWidgets('shows empty state when no workers', (tester) async {
      await pumpWorkersPage(tester, workers: []);
      expect(find.text('No workers yet'), findsOneWidget);
    });

    testWidgets('shows error on workers provider error', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            workersProvider.overrideWith(_ErrorWorkersNotifier.new),
            layersProvider.overrideWith(
              () => _FakeLayersNotifier(fakeLayers()),
            ),
          ],
          child: const MaterialApp(home: WorkersPage()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Error:'), findsOneWidget);
    });

    testWidgets('shows No workers for layer without workers', (tester) async {
      await pumpWorkersPage(
        tester,
        workers: [
          const WorkerDefinition(
            name: 'writer-1',
            layerName: 'Draft',
            systemPrompt: 'You are a writer.',
          ),
        ],
        layers: [
          const LayerDefinition(
            name: 'Draft',
            inputTypes: ['text'],
            outputTypes: ['draft'],
          ),
          const LayerDefinition(
            name: 'Review',
            inputTypes: ['draft'],
            outputTypes: ['review'],
            order: 1,
          ),
        ],
      );
      expect(find.text('No workers'), findsOneWidget);
    });
  });
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

class _ErrorWorkersNotifier extends WorkersNotifier {
  @override
  Future<List<WorkerDefinition>> build() async => throw Exception('db failed');
}
