import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gyeol/data/database/database.dart';
import 'package:gyeol/data/providers/core_providers.dart';
import 'package:gyeol/data/providers/graph_state_provider.dart';

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

  group('GraphState', () {
    test('has correct defaults', () {
      const state = GraphState();
      expect(state.nodePositions, isEmpty);
      expect(state.viewportX, 0);
      expect(state.viewportY, 0);
      expect(state.viewportZoom, 1);
    });

    test('copyWith preserves unchanged fields', () {
      const state = GraphState(
        nodePositions: {'a': Offset(10, 20)},
        viewportX: 5,
        viewportY: 10,
        viewportZoom: 2,
      );
      final copy = state.copyWith(viewportX: 99);
      expect(copy.nodePositions, state.nodePositions);
      expect(copy.viewportX, 99);
      expect(copy.viewportY, 10);
      expect(copy.viewportZoom, 2);
    });

    test('copyWith replaces nodePositions', () {
      const state = GraphState(nodePositions: {'a': Offset(1, 2)});
      final copy = state.copyWith(nodePositions: const {'b': Offset(3, 4)});
      expect(copy.nodePositions, const {'b': Offset(3, 4)});
    });
  });

  group('GraphStateNotifier', () {
    test('build returns default state when no saved data', () async {
      final state = await container.read(graphStateProvider.future);
      expect(state.nodePositions, isEmpty);
      expect(state.viewportX, 0);
      expect(state.viewportY, 0);
      expect(state.viewportZoom, 1);
    });

    test('savePositions persists and updates state', () async {
      final notifier = container.read(graphStateProvider.notifier);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      const positions = <String, Offset>{
        'layer-1': Offset(100, 200),
        'layer-2': Offset(300, 400),
      };
      await notifier.savePositions(positions);

      final state = await container.read(graphStateProvider.future);
      expect(state.nodePositions['layer-1'], const Offset(100, 200));
      expect(state.nodePositions['layer-2'], const Offset(300, 400));
    });

    test('savePositions preserves viewport', () async {
      final notifier = container.read(graphStateProvider.notifier);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      await notifier.saveViewport(10, 20, 3);
      await notifier.savePositions(const {'a': Offset(1, 2)});

      final state = await container.read(graphStateProvider.future);
      expect(state.viewportX, 10);
      expect(state.viewportY, 20);
      expect(state.viewportZoom, 3);
      expect(state.nodePositions, const {'a': Offset(1, 2)});
    });

    test('saveViewport persists and updates state', () async {
      final notifier = container.read(graphStateProvider.notifier);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      await notifier.saveViewport(42.5, 17.3, 0.8);

      final state = await container.read(graphStateProvider.future);
      expect(state.viewportX, closeTo(42.5, 0.01));
      expect(state.viewportY, closeTo(17.3, 0.01));
      expect(state.viewportZoom, closeTo(0.8, 0.01));
    });

    test('saveViewport preserves positions', () async {
      final notifier = container.read(graphStateProvider.notifier);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      await notifier.savePositions(const {'x': Offset(5, 10)});
      await notifier.saveViewport(1, 2, 3);

      final state = await container.read(graphStateProvider.future);
      expect(state.nodePositions, const {'x': Offset(5, 10)});
    });

    test('clearPositions removes all positions', () async {
      final notifier = container.read(graphStateProvider.notifier);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      await notifier.savePositions(const {
        'a': Offset(1, 1),
        'b': Offset(2, 2),
      });

      var state = await container.read(graphStateProvider.future);
      expect(state.nodePositions, isNotEmpty);

      await notifier.clearPositions();

      state = await container.read(graphStateProvider.future);
      expect(state.nodePositions, isEmpty);
    });

    test('clearPositions preserves viewport', () async {
      final notifier = container.read(graphStateProvider.notifier);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      await notifier.saveViewport(10, 20, 2);
      await notifier.savePositions(const {'a': Offset(1, 1)});
      await notifier.clearPositions();

      final state = await container.read(graphStateProvider.future);
      expect(state.nodePositions, isEmpty);
      expect(state.viewportX, 10);
      expect(state.viewportY, 20);
      expect(state.viewportZoom, 2);
    });

    test('state persists across provider rebuild', () async {
      final notifier = container.read(graphStateProvider.notifier);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      await notifier.savePositions(const {'persist': Offset(50, 60)});
      await notifier.saveViewport(7, 8, 1.5);

      container.invalidate(graphStateProvider);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final state = await container.read(graphStateProvider.future);
      expect(state.nodePositions['persist'], const Offset(50, 60));
      expect(state.viewportX, 7);
      expect(state.viewportY, 8);
      expect(state.viewportZoom, 1.5);
    });
  });
}
