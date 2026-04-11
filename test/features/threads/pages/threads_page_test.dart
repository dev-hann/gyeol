import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gyeol/data/models/app_models.dart';
import 'package:gyeol/data/providers/app_providers.dart';
import 'package:gyeol/features/threads/pages/threads_page.dart';

void main() {
  final fakeThreads = [
    const ThreadDefinition(
      name: 'review',
      path: '/home/user/project',
      layerNames: ['L1', 'L2'],
    ),
    const ThreadDefinition(
      name: 'analysis',
      path: '/data/src',
      layerNames: [],
      enabled: false,
      status: ThreadStatus.completed,
    ),
  ];

  final fakeLayers = [
    const LayerDefinition(
      name: 'L1',
      inputTypes: ['txt'],
      outputTypes: ['json'],
    ),
    const LayerDefinition(
      name: 'L2',
      inputTypes: ['json'],
      outputTypes: ['md'],
    ),
  ];

  Future<void> pumpThreadsPage(
    WidgetTester tester, {
    List<ThreadDefinition>? threads,
    List<LayerDefinition>? layers,
    bool threadsError = false,
  }) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          threadsProvider.overrideWith(
            () => _FakeThreadsNotifier(
              threads: threads ?? fakeThreads,
              throwError: threadsError,
            ),
          ),
          layersProvider.overrideWith(
            () => _FakeLayersNotifier(layers ?? fakeLayers),
          ),
        ],
        child: const MaterialApp(home: ThreadsPage()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  group('ThreadsPage', () {
    testWidgets('renders PageHeader with Threads title', (tester) async {
      await pumpThreadsPage(tester);
      expect(find.text('Threads'), findsOneWidget);
    });

    testWidgets('renders description text', (tester) async {
      await pumpThreadsPage(tester);
      expect(
        find.text('Execution units combining layers with a working directory'),
        findsOneWidget,
      );
    });

    testWidgets('renders Add Thread button', (tester) async {
      await pumpThreadsPage(tester);
      expect(find.text('Add Thread'), findsOneWidget);
    });

    testWidgets('renders thread cards with names', (tester) async {
      await pumpThreadsPage(tester);
      expect(find.text('review'), findsOneWidget);
      expect(find.text('analysis'), findsOneWidget);
    });

    testWidgets('renders thread paths', (tester) async {
      await pumpThreadsPage(tester);
      expect(find.text('/home/user/project'), findsOneWidget);
      expect(find.text('/data/src'), findsOneWidget);
    });

    testWidgets('renders layer chip count for threads with layers', (
      tester,
    ) async {
      await pumpThreadsPage(tester);
      expect(find.text('2 layers'), findsOneWidget);
    });

    testWidgets('renders run button per thread', (tester) async {
      await pumpThreadsPage(tester);
      expect(find.byTooltip('Run Thread'), findsNWidgets(2));
    });

    testWidgets('renders edit button per thread', (tester) async {
      await pumpThreadsPage(tester);
      expect(find.byTooltip('Edit'), findsNWidgets(2));
    });

    testWidgets('renders delete button per thread', (tester) async {
      await pumpThreadsPage(tester);
      expect(find.byTooltip('Delete'), findsNWidgets(2));
    });

    testWidgets('shows empty state when no threads', (tester) async {
      await pumpThreadsPage(tester, threads: []);
      expect(find.text('No threads yet'), findsOneWidget);
      expect(
        find.text('Create a thread to run layers against a directory'),
        findsOneWidget,
      );
    });

    testWidgets('shows empty state Add Thread button', (tester) async {
      await pumpThreadsPage(tester, threads: []);
      final addButtons = find.text('Add Thread');
      expect(addButtons, findsNWidgets(2));
    });

    testWidgets('shows error on threads provider error', (tester) async {
      await pumpThreadsPage(tester, threadsError: true);
      expect(find.textContaining('Error:'), findsOneWidget);
    });

    testWidgets('renders status badges for threads', (tester) async {
      await pumpThreadsPage(tester);
      expect(find.text('Idle'), findsOneWidget);
      expect(find.text('Completed'), findsOneWidget);
    });
  });
}

class _FakeThreadsNotifier extends ThreadsNotifier {
  _FakeThreadsNotifier({required this.threads, this.throwError = false});

  final List<ThreadDefinition> threads;
  final bool throwError;

  @override
  Future<List<ThreadDefinition>> build() async {
    if (throwError) throw Exception('db failed');
    return threads;
  }

  @override
  Future<void> saveThread(ThreadDefinition thread) async {
    state = AsyncData([...threads, thread]);
  }

  @override
  Future<void> deleteThread(String name) async {
    state = AsyncData(threads.where((t) => t.name != name).toList());
  }
}

class _FakeLayersNotifier extends LayersNotifier {
  _FakeLayersNotifier(this.layers);
  final List<LayerDefinition> layers;

  @override
  Future<List<LayerDefinition>> build() async => layers;
}
