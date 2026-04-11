import 'package:flutter_test/flutter_test.dart';
import 'package:gyeol/data/models/app_models.dart';
import 'package:gyeol/features/layers/graph/graph_utils.dart';
import 'package:vyuh_node_flow/vyuh_node_flow.dart';

void main() {
  group('LayerGraphData', () {
    test('constructor sets all fields', () {
      const data = LayerGraphData(
        layerName: 'L1',
        inputTypes: ['text'],
        outputTypes: ['json'],
        workerCount: 1,
        enabled: true,
      );
      expect(data.layerName, 'L1');
      expect(data.inputTypes, ['text']);
      expect(data.outputTypes, ['json']);
      expect(data.workerCount, 1);
      expect(data.enabled, isTrue);
    });

    test('runningTasks defaults to 0', () {
      const data = LayerGraphData(
        layerName: 'L1',
        inputTypes: [],
        outputTypes: [],
        workerCount: 0,
        enabled: true,
      );
      expect(data.runningTasks, 0);
    });

    test('runningTasks can be set', () {
      const data = LayerGraphData(
        layerName: 'L1',
        inputTypes: [],
        outputTypes: [],
        workerCount: 0,
        enabled: false,
        runningTasks: 5,
      );
      expect(data.runningTasks, 5);
      expect(data.enabled, isFalse);
    });
  });

  group('buildNodes', () {
    test('returns empty list for empty layers', () {
      final nodes = buildNodes([], [], []);
      expect(nodes, isEmpty);
    });

    test('creates one node per layer', () {
      final layers = [
        const LayerDefinition(
          name: 'L1',
          inputTypes: ['text'],
          outputTypes: ['json'],
        ),
        const LayerDefinition(
          name: 'L2',
          inputTypes: ['json'],
          outputTypes: ['result'],
          order: 1,
        ),
      ];
      final nodes = buildNodes(layers, [], []);
      expect(nodes, hasLength(2));
    });

    test('node id matches layer name', () {
      final layers = [
        const LayerDefinition(
          name: 'Alpha',
          inputTypes: ['text'],
          outputTypes: ['json'],
        ),
      ];
      final nodes = buildNodes(layers, [], []);
      expect(nodes.first.id, 'Alpha');
    });

    test('nodes have input and output ports', () {
      final layers = [
        const LayerDefinition(
          name: 'L1',
          inputTypes: ['text'],
          outputTypes: ['json'],
        ),
      ];
      final nodes = buildNodes(layers, [], []);
      final node = nodes.first;
      expect(node.ports, hasLength(2));
      expect(node.ports.any((p) => p.type == PortType.input), isTrue);
      expect(node.ports.any((p) => p.type == PortType.output), isTrue);
    });

    test('nodes are separated by kNodeWidth + kRankSep horizontally', () {
      final layers = [
        const LayerDefinition(
          name: 'L0',
          inputTypes: ['text'],
          outputTypes: ['json'],
        ),
        const LayerDefinition(
          name: 'L1',
          inputTypes: ['json'],
          outputTypes: ['result'],
          order: 1,
        ),
      ];
      final nodes = buildNodes(layers, [], []);
      final xPositions = nodes.map((n) => n.position.value.dx).toList();
      expect(xPositions, hasLength(2));
      final diff = (xPositions[1] - xPositions[0]).abs();
      expect(diff, kNodeWidth + kRankSep);
    });

    test('counts running tasks per layer in node data', () {
      final layers = [
        const LayerDefinition(
          name: 'L1',
          inputTypes: ['text'],
          outputTypes: ['json'],
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
      final nodes = buildNodes(layers, tasks, []);
      expect(nodes.first.data.runningTasks, 1);
    });

    test('node data contains layer info', () {
      final layers = [
        const LayerDefinition(
          name: 'L1',
          inputTypes: ['a', 'b'],
          outputTypes: ['c'],
          enabled: false,
        ),
      ];
      final workers = [
        const WorkerDefinition(name: 'w1', layerName: 'L1', systemPrompt: 'p1'),
        const WorkerDefinition(name: 'w2', layerName: 'L1', systemPrompt: 'p2'),
      ];
      final nodes = buildNodes(layers, [], workers);
      final data = nodes.first.data;
      expect(data.layerName, 'L1');
      expect(data.inputTypes, ['a', 'b']);
      expect(data.outputTypes, ['c']);
      expect(data.workerCount, 2);
      expect(data.enabled, isFalse);
    });
  });

  group('buildConnections', () {
    test('connects layers with overlapping output/input types', () {
      final layers = [
        const LayerDefinition(
          name: 'A',
          inputTypes: ['text'],
          outputTypes: ['json'],
        ),
        const LayerDefinition(
          name: 'B',
          inputTypes: ['json'],
          outputTypes: ['result'],
          order: 1,
        ),
      ];
      final connections = buildConnections(layers, <(String, String)>{});
      expect(connections, isNotEmpty);
      expect(
        connections.any((c) => c.sourceNodeId == 'A' && c.targetNodeId == 'B'),
        isTrue,
      );
    });

    test('does not connect layers without type overlap', () {
      final layers = [
        const LayerDefinition(
          name: 'A',
          inputTypes: ['text'],
          outputTypes: ['json'],
        ),
        const LayerDefinition(
          name: 'B',
          inputTypes: ['image'],
          outputTypes: ['result'],
          order: 1,
        ),
      ];
      final connections = buildConnections(layers, <(String, String)>{});
      expect(connections, isEmpty);
    });

    test('respects removedConnections', () {
      final layers = [
        const LayerDefinition(
          name: 'A',
          inputTypes: ['text'],
          outputTypes: ['json'],
        ),
        const LayerDefinition(
          name: 'B',
          inputTypes: ['json'],
          outputTypes: ['result'],
          order: 1,
        ),
      ];
      final connections = buildConnections(layers, {('A', 'B')});
      expect(connections, isEmpty);
    });

    test('connection source/target port ids match layer port ids', () {
      final layers = [
        const LayerDefinition(
          name: 'A',
          inputTypes: ['text'],
          outputTypes: ['json'],
        ),
        const LayerDefinition(
          name: 'B',
          inputTypes: ['json'],
          outputTypes: ['result'],
          order: 1,
        ),
      ];
      final connections = buildConnections(layers, <(String, String)>{});
      final conn = connections.first;
      expect(conn.sourcePortId, 'A-out');
      expect(conn.targetPortId, 'B-in');
    });

    test('returns empty for empty layers', () {
      final connections = buildConnections([], <(String, String)>{});
      expect(connections, isEmpty);
    });

    test('handles multiple connections', () {
      final layers = [
        const LayerDefinition(
          name: 'A',
          inputTypes: ['text'],
          outputTypes: ['json', 'data'],
        ),
        const LayerDefinition(
          name: 'B',
          inputTypes: ['json'],
          outputTypes: ['result'],
          order: 1,
        ),
        const LayerDefinition(
          name: 'C',
          inputTypes: ['data'],
          outputTypes: ['report'],
          order: 2,
        ),
      ];
      final connections = buildConnections(layers, <(String, String)>{});
      expect(connections, hasLength(2));
    });
  });
}
