import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gyeol/data/models/app_models.dart';
import 'package:gyeol/features/layers/graph/flow_canvas.dart';
import 'package:gyeol/features/layers/graph/graph_utils.dart';
import 'package:gyeol/features/layers/graph/layer_node_widget.dart';
import 'package:vyuh_node_flow/vyuh_node_flow.dart';

NodeFlowController<LayerGraphData, void> createTestController() {
  final nodes = buildNodes(
    [
      const LayerDefinition(
        id: 1,
        threadId: 1,
        name: 'TestLayer',
        inputTypes: ['text'],
        outputTypes: ['json'],
      ),
    ],
    [],
    [
      const WorkerDefinition(
        id: 1,
        name: 'w1',
        layerId: 1,
        systemPrompt: 'test',
      ),
    ],
    [],
  );
  return NodeFlowController<LayerGraphData, void>(nodes: nodes);
}

Widget buildWidget(
  NodeFlowController<LayerGraphData, void> controller, {
  void Function(String)? onNodeTap,
}) {
  return MaterialApp(
    home: Scaffold(
      body: FlowCanvas(controller: controller, onNodeTap: onNodeTap ?? (_) {}),
    ),
  );
}

void main() {
  group('FlowCanvas', () {
    testWidgets('renders NodeFlowEditor widget', (tester) async {
      final controller = createTestController();
      await tester.pumpWidget(buildWidget(controller));
      expect(find.byType(NodeFlowEditor<LayerGraphData, void>), findsOneWidget);
    });

    testWidgets('renders layer name via LayerNodeWidget', (tester) async {
      final controller = createTestController();
      await tester.pumpWidget(buildWidget(controller));
      await tester.pumpAndSettle();
      expect(find.text('TestLayer'), findsOneWidget);
    });

    testWidgets('renders worker count text', (tester) async {
      final controller = createTestController();
      await tester.pumpWidget(buildWidget(controller));
      await tester.pumpAndSettle();
      expect(find.text('1 worker'), findsOneWidget);
    });

    testWidgets('renders output type tag', (tester) async {
      final controller = createTestController();
      await tester.pumpWidget(buildWidget(controller));
      await tester.pumpAndSettle();
      expect(find.text('json'), findsOneWidget);
    });

    testWidgets('renders with empty controller', (tester) async {
      final controller = NodeFlowController<LayerGraphData, void>();
      await tester.pumpWidget(buildWidget(controller));
      expect(find.byType(NodeFlowEditor<LayerGraphData, void>), findsOneWidget);
    });

    testWidgets('renders disabled layer with reduced opacity', (tester) async {
      final nodes = buildNodes(
        [
          const LayerDefinition(
            id: 1,
            threadId: 1,
            name: 'DisabledLayer',
            inputTypes: [],
            outputTypes: [],
            enabled: false,
          ),
        ],
        [],
        [],
        [],
      );
      final controller = NodeFlowController<LayerGraphData, void>(nodes: nodes);
      await tester.pumpWidget(buildWidget(controller));
      await tester.pumpAndSettle();

      final opacity = tester.widget<Opacity>(find.byType(Opacity).first);
      expect(opacity.opacity, 0.5);
    });

    testWidgets('contains LayerNodeWidget with correct data', (tester) async {
      final controller = createTestController();
      await tester.pumpWidget(buildWidget(controller));
      await tester.pumpAndSettle();

      expect(find.byType(LayerNodeWidget), findsOneWidget);
      final nodeWidget = tester.widget<LayerNodeWidget>(
        find.byType(LayerNodeWidget),
      );
      expect(nodeWidget.name, 'TestLayer');
      expect(nodeWidget.enabled, isTrue);
      expect(nodeWidget.workerCount, 1);
    });
  });
}
