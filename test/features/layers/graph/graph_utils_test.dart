import 'package:flutter_test/flutter_test.dart';
import 'package:gyeol/data/models/app_models.dart';
import 'package:gyeol/features/layers/graph/graph_utils.dart';

void main() {
  group('LayerGraphData', () {
    test('constructor sets all fields', () {
      const data = LayerGraphData(
        layerName: 'L1',
        inputTypes: ['text'],
        outputTypes: ['json'],
        workerNames: ['w1'],
        enabled: true,
      );
      expect(data.layerName, 'L1');
      expect(data.inputTypes, ['text']);
      expect(data.outputTypes, ['json']);
      expect(data.workerNames, ['w1']);
      expect(data.enabled, isTrue);
    });

    test('runningTasks defaults to 0', () {
      const data = LayerGraphData(
        layerName: 'L1',
        inputTypes: [],
        outputTypes: [],
        workerNames: [],
        enabled: true,
      );
      expect(data.runningTasks, 0);
    });

    test('runningTasks can be set', () {
      const data = LayerGraphData(
        layerName: 'L1',
        inputTypes: [],
        outputTypes: [],
        workerNames: [],
        enabled: false,
        runningTasks: 5,
      );
      expect(data.runningTasks, 5);
      expect(data.enabled, isFalse);
    });
  });

  group('DataSerializerImpl', () {
    final serializer = DataSerializerImpl();

    test('fromJson returns null for null input', () {
      expect(serializer.fromJson(null), isNull);
    });

    test('fromJson creates LayerGraphData from valid map', () {
      final result = serializer.fromJson({
        'layerName': 'L1',
        'inputTypes': ['a'],
        'outputTypes': ['b'],
        'workerNames': ['w1'],
        'enabled': false,
        'runningTasks': 3,
      });
      expect(result, isNotNull);
      expect(result!.layerName, 'L1');
      expect(result.inputTypes, ['a']);
      expect(result.outputTypes, ['b']);
      expect(result.workerNames, ['w1']);
      expect(result.enabled, isFalse);
      expect(result.runningTasks, 3);
    });

    test('fromJson uses defaults for missing fields', () {
      final result = serializer.fromJson({});
      expect(result, isNotNull);
      expect(result!.layerName, '');
      expect(result.inputTypes, isEmpty);
      expect(result.outputTypes, isEmpty);
      expect(result.workerNames, isEmpty);
      expect(result.enabled, isTrue);
      expect(result.runningTasks, 0);
    });

    test('fromJson handles partial data', () {
      final result = serializer.fromJson({'layerName': 'L2', 'enabled': false});
      expect(result!.layerName, 'L2');
      expect(result.enabled, isFalse);
      expect(result.inputTypes, isEmpty);
      expect(result.runningTasks, 0);
    });

    test('toJson returns null for null input', () {
      expect(serializer.toJson(null), isNull);
    });

    test('toJson produces correct map', () {
      const data = LayerGraphData(
        layerName: 'L1',
        inputTypes: ['a'],
        outputTypes: ['b'],
        workerNames: ['w1'],
        enabled: true,
        runningTasks: 2,
      );
      final result = serializer.toJson(data);
      expect(result, {
        'layerName': 'L1',
        'inputTypes': ['a'],
        'outputTypes': ['b'],
        'workerNames': ['w1'],
        'enabled': true,
        'runningTasks': 2,
      });
    });

    test('toJson round-trips through fromJson', () {
      const data = LayerGraphData(
        layerName: 'X',
        inputTypes: ['t1', 't2'],
        outputTypes: ['o1'],
        workerNames: ['w1', 'w2'],
        enabled: false,
        runningTasks: 7,
      );
      final json = serializer.toJson(data)!;
      final restored = serializer.fromJson(json)!;
      expect(restored.layerName, data.layerName);
      expect(restored.inputTypes, data.inputTypes);
      expect(restored.outputTypes, data.outputTypes);
      expect(restored.workerNames, data.workerNames);
      expect(restored.enabled, data.enabled);
      expect(restored.runningTasks, data.runningTasks);
    });
  });

  group('buildDashboard', () {
    test('returns empty dashboard for empty layers', () {
      final dashboard = buildDashboard([], []);
      expect(dashboard.elements, isEmpty);
    });

    test('creates one element per layer', () {
      final layers = [
        const LayerDefinition(
          name: 'L1',
          inputTypes: ['text'],
          outputTypes: ['json'],
          workerNames: ['w1'],
        ),
        const LayerDefinition(
          name: 'L2',
          inputTypes: ['json'],
          outputTypes: ['result'],
          workerNames: ['w2'],
          order: 1,
        ),
      ];
      final dashboard = buildDashboard(layers, []);
      expect(dashboard.elements, hasLength(2));
    });

    test('element text matches layer name', () {
      final layers = [
        const LayerDefinition(
          name: 'Alpha',
          inputTypes: ['text'],
          outputTypes: ['json'],
          workerNames: ['w1'],
        ),
      ];
      final dashboard = buildDashboard(layers, []);
      expect(dashboard.elements.first.text, 'Alpha');
    });

    test('elements are separated by kNodeWidth + kRankSep horizontally', () {
      final layers = [
        const LayerDefinition(
          name: 'L0',
          inputTypes: ['text'],
          outputTypes: ['json'],
          workerNames: ['w1'],
        ),
        const LayerDefinition(
          name: 'L1',
          inputTypes: ['json'],
          outputTypes: ['result'],
          workerNames: ['w2'],
          order: 1,
        ),
      ];
      final dashboard = buildDashboard(layers, []);
      final positions = dashboard.elements.map((e) => e.position.dx).toList();
      expect(positions, hasLength(2));
      final diff = (positions[1] - positions[0]).abs();
      expect(diff, kNodeWidth + kRankSep);
    });

    test('connects layers with overlapping output/input types', () {
      final layers = [
        const LayerDefinition(
          name: 'A',
          inputTypes: ['text'],
          outputTypes: ['json'],
          workerNames: ['w1'],
        ),
        const LayerDefinition(
          name: 'B',
          inputTypes: ['json'],
          outputTypes: ['result'],
          workerNames: ['w2'],
          order: 1,
        ),
      ];
      final dashboard = buildDashboard(layers, []);
      expect(dashboard.elements.first.next, isNotEmpty);
    });

    test('does not connect layers without type overlap', () {
      final layers = [
        const LayerDefinition(
          name: 'A',
          inputTypes: ['text'],
          outputTypes: ['json'],
          workerNames: ['w1'],
        ),
        const LayerDefinition(
          name: 'B',
          inputTypes: ['image'],
          outputTypes: ['result'],
          workerNames: ['w2'],
          order: 1,
        ),
      ];
      final dashboard = buildDashboard(layers, []);
      expect(dashboard.elements.first.next, isEmpty);
    });

    test('counts running tasks per layer in element data', () {
      final layers = [
        const LayerDefinition(
          name: 'L1',
          inputTypes: ['text'],
          outputTypes: ['json'],
          workerNames: ['w1'],
        ),
      ];
      final tasks = [
        const AppTask(
          id: 't1',
          taskType: 'test',
          payload: null,
          priority: TaskPriority.high,
          status: TaskStatus.running,
          layerName: 'L1',
          createdAt: 0,
          updatedAt: 0,
        ),
        const AppTask(
          id: 't2',
          taskType: 'test',
          payload: null,
          priority: TaskPriority.low,
          status: TaskStatus.pending,
          layerName: 'L1',
          createdAt: 0,
          updatedAt: 0,
        ),
      ];
      final dashboard = buildDashboard(layers, tasks);
      final data = dashboard.elements.first.elementData!;
      expect(data.runningTasks, 1);
    });

    test('syncDashboard replaces all elements', () {
      final original = buildDashboard([
        const LayerDefinition(
          name: 'Old',
          inputTypes: ['a'],
          outputTypes: ['b'],
          workerNames: ['w1'],
        ),
      ], []);

      syncDashboard(original, [
        const LayerDefinition(
          name: 'New1',
          inputTypes: ['x'],
          outputTypes: ['y'],
          workerNames: ['w2'],
        ),
        const LayerDefinition(
          name: 'New2',
          inputTypes: ['y'],
          outputTypes: ['z'],
          workerNames: ['w3'],
          order: 1,
        ),
      ], []);

      expect(original.elements, hasLength(2));
      expect(original.elements.any((e) => e.text == 'New1'), isTrue);
      expect(original.elements.any((e) => e.text == 'New2'), isTrue);
    });
  });
}
