import 'package:flutter_test/flutter_test.dart';
import 'package:gyeol/data/models/app_models.dart';
import 'package:gyeol/data/repositories/connection_repository.dart';
import 'package:gyeol/features/layers/graph/graph_utils.dart';
import 'package:vyuh_node_flow/vyuh_node_flow.dart';

void main() {
  group('LayerGraphData', () {
    test('constructor sets all fields', () {
      const data = LayerGraphData(
        layerId: 1,
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
        layerId: 1,
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
        layerId: 1,
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
      final nodes = buildNodes([], [], [], []);
      expect(nodes, isEmpty);
    });

    test('creates one node per layer', () {
      final layers = [
        const LayerDefinition(
          id: 1,
          name: 'L1',
          inputTypes: ['text'],
          outputTypes: ['json'],
        ),
        const LayerDefinition(
          id: 2,
          name: 'L2',
          inputTypes: ['json'],
          outputTypes: ['result'],
          order: 1,
        ),
      ];
      final nodes = buildNodes(layers, [], [], []);
      expect(nodes, hasLength(2));
    });

    test('node id matches layer id string', () {
      final layers = [
        const LayerDefinition(
          id: 42,
          name: 'Alpha',
          inputTypes: ['text'],
          outputTypes: ['json'],
        ),
      ];
      final nodes = buildNodes(layers, [], [], []);
      expect(nodes.first.id, '42');
    });

    test('nodes have input and output ports', () {
      final layers = [
        const LayerDefinition(
          id: 1,
          name: 'L1',
          inputTypes: ['text'],
          outputTypes: ['json'],
        ),
      ];
      final nodes = buildNodes(layers, [], [], []);
      final node = nodes.first;
      expect(node.ports, hasLength(2));
      expect(node.ports.any((p) => p.type == PortType.input), isTrue);
      expect(node.ports.any((p) => p.type == PortType.output), isTrue);
    });

    test('nodes are separated by kNodeWidth + kRankSep horizontally', () {
      final layers = [
        const LayerDefinition(
          id: 1,
          name: 'L0',
          inputTypes: ['text'],
          outputTypes: ['json'],
        ),
        const LayerDefinition(
          id: 2,
          name: 'L1',
          inputTypes: ['json'],
          outputTypes: ['result'],
          order: 1,
        ),
      ];
      final connections = [
        const LayerConnectionData(sourceLayerId: 1, targetLayerId: 2),
      ];
      final nodes = buildNodes(layers, [], [], connections);
      final xPositions = nodes.map((n) => n.position.value.dx).toList();
      expect(xPositions, hasLength(2));
      final diff = (xPositions[1] - xPositions[0]).abs();
      expect(diff, kNodeWidth + kRankSep);
    });

    test('counts running tasks per layer in node data', () {
      final layers = [
        const LayerDefinition(
          id: 1,
          name: 'L1',
          inputTypes: ['text'],
          outputTypes: ['json'],
        ),
      ];
      final tasks = [
        const AppTask(
          id: 0,
          uuid: 't1',
          taskType: 'test',
          payload: null,
          priority: TaskPriority.high,
          status: TaskStatus.running,
          layerId: 1,
          createdAt: 0,
          updatedAt: 0,
        ),
        const AppTask(
          id: 0,
          uuid: 't2',
          taskType: 'test',
          payload: null,
          priority: TaskPriority.low,
          status: TaskStatus.pending,
          layerId: 1,
          createdAt: 0,
          updatedAt: 0,
        ),
      ];
      final nodes = buildNodes(layers, tasks, [], []);
      expect(nodes.first.data.runningTasks, 1);
    });

    test('node data contains layer info', () {
      final layers = [
        const LayerDefinition(
          id: 1,
          name: 'L1',
          inputTypes: ['a', 'b'],
          outputTypes: ['c'],
          enabled: false,
        ),
      ];
      final workers = [
        const WorkerDefinition(
          id: 1,
          name: 'w1',
          layerId: 1,
          systemPrompt: 'p1',
        ),
        const WorkerDefinition(
          id: 2,
          name: 'w2',
          layerId: 1,
          systemPrompt: 'p2',
        ),
      ];
      final nodes = buildNodes(layers, [], workers, []);
      final data = nodes.first.data;
      expect(data.layerName, 'L1');
      expect(data.inputTypes, ['a', 'b']);
      expect(data.outputTypes, ['c']);
      expect(data.workerCount, 2);
      expect(data.enabled, isFalse);
    });
  });

  group('buildConnections', () {
    test('creates connections from LayerConnectionData', () {
      final connections = [
        const LayerConnectionData(sourceLayerId: 1, targetLayerId: 2),
      ];
      final result = buildConnections(connections);
      expect(result, hasLength(1));
      expect(result.first.sourceNodeId, '1');
      expect(result.first.targetNodeId, '2');
    });

    test('returns empty for empty connections', () {
      final result = buildConnections([]);
      expect(result, isEmpty);
    });

    test('handles multiple connections', () {
      final connections = [
        const LayerConnectionData(sourceLayerId: 1, targetLayerId: 2),
        const LayerConnectionData(sourceLayerId: 1, targetLayerId: 3),
      ];
      final result = buildConnections(connections);
      expect(result, hasLength(2));
    });

    test('connection port ids match node port convention', () {
      final connections = [
        const LayerConnectionData(sourceLayerId: 10, targetLayerId: 20),
      ];
      final result = buildConnections(connections);
      final conn = result.first;
      expect(conn.sourcePortId, '10-out');
      expect(conn.targetPortId, '20-in');
    });
  });

  group('layoutGraph', () {
    test('returns empty map for empty layers', () {
      final result = layoutGraph([], []);
      expect(result, isEmpty);
    });

    test('positions single node at base offset', () {
      final layers = [
        const LayerDefinition(
          id: 1,
          name: 'A',
          inputTypes: ['text'],
          outputTypes: ['json'],
        ),
      ];
      final result = layoutGraph(layers, []);
      expect(result, contains('1'));
      expect(result['1']!.dx, 80.0);
      expect(result['1']!.dy, 80.0);
    });

    test('positions connected nodes horizontally', () {
      final layers = [
        const LayerDefinition(
          id: 1,
          name: 'A',
          inputTypes: ['text'],
          outputTypes: ['json'],
        ),
        const LayerDefinition(
          id: 2,
          name: 'B',
          inputTypes: ['json'],
          outputTypes: ['result'],
          order: 1,
        ),
      ];
      final connections = [
        const LayerConnectionData(sourceLayerId: 1, targetLayerId: 2),
      ];
      final result = layoutGraph(layers, connections);
      expect(result['2']!.dx, greaterThan(result['1']!.dx));
    });

    test('ignores connections for non-existent nodes', () {
      final layers = [
        const LayerDefinition(
          id: 1,
          name: 'A',
          inputTypes: ['text'],
          outputTypes: ['json'],
        ),
      ];
      final connections = [
        const LayerConnectionData(sourceLayerId: 1, targetLayerId: 999),
      ];
      final result = layoutGraph(layers, connections);
      expect(result, hasLength(1));
    });
  });
}
