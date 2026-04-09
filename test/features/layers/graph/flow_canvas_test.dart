import 'package:flutter/material.dart';
import 'package:flutter_flow_chart/flutter_flow_chart.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gyeol/data/models/app_models.dart';
import 'package:gyeol/features/layers/graph/flow_canvas.dart';
import 'package:gyeol/features/layers/graph/graph_utils.dart';
import 'package:gyeol/features/layers/graph/layer_node_widget.dart';

void main() {
  Dashboard<LayerGraphData> createTestDashboard() {
    return buildDashboard([
      const LayerDefinition(
        name: 'TestLayer',
        inputTypes: ['text'],
        outputTypes: ['json'],
        workerNames: ['w1'],
      ),
    ], []);
  }

  Widget buildWidget(
    Dashboard<LayerGraphData> dashboard, {
    void Function(String)? onNodeTap,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: FlowCanvas(dashboard: dashboard, onNodeTap: onNodeTap ?? (_) {}),
      ),
    );
  }

  group('FlowCanvas', () {
    testWidgets('renders FlowChart widget', (tester) async {
      final dashboard = createTestDashboard();
      await tester.pumpWidget(buildWidget(dashboard));
      expect(find.byType(FlowChart<LayerGraphData>), findsOneWidget);
    });

    testWidgets('renders layer name via LayerNodeWidget', (tester) async {
      final dashboard = createTestDashboard();
      await tester.pumpWidget(buildWidget(dashboard));
      await tester.pumpAndSettle();
      expect(find.text('TestLayer'), findsOneWidget);
    });

    testWidgets('renders worker count text', (tester) async {
      final dashboard = createTestDashboard();
      await tester.pumpWidget(buildWidget(dashboard));
      await tester.pumpAndSettle();
      expect(find.text('1 worker'), findsOneWidget);
    });

    testWidgets('customElementBuilder returns SizedBox for null data', (
      tester,
    ) async {
      final dashboard = Dashboard<LayerGraphData>(
        dataSerializer: DataSerializerImpl(),
      );
      dashboard.addElement(
        FlowElement<LayerGraphData>(
          size: const Size(100, 100),
          text: 'empty',
          kind: ElementKind.custom,
        ),
      );

      await tester.pumpWidget(buildWidget(dashboard));
      final flowChart = tester.widget<FlowChart<LayerGraphData>>(
        find.byType(FlowChart<LayerGraphData>),
      );

      final builder = flowChart.customElementBuilder!;
      final context = tester.element(find.byType(FlowChart<LayerGraphData>));
      final result = builder(context, dashboard.elements.first);

      expect(result, isA<SizedBox>());
    });

    testWidgets('customElementBuilder returns LayerNodeWidget for valid data', (
      tester,
    ) async {
      final dashboard = createTestDashboard();
      await tester.pumpWidget(buildWidget(dashboard));

      final flowChart = tester.widget<FlowChart<LayerGraphData>>(
        find.byType(FlowChart<LayerGraphData>),
      );

      final builder = flowChart.customElementBuilder!;
      final context = tester.element(find.byType(FlowChart<LayerGraphData>));
      final result = builder(context, dashboard.elements.first);

      expect(result, isA<LayerNodeWidget>());
      final node = result as LayerNodeWidget;
      expect(node.name, 'TestLayer');
      expect(node.enabled, isTrue);
      expect(node.workerCount, 1);
    });

    testWidgets('onElementPressed callback is wired', (tester) async {
      final dashboard = createTestDashboard();
      await tester.pumpWidget(buildWidget(dashboard));

      final flowChart = tester.widget<FlowChart<LayerGraphData>>(
        find.byType(FlowChart<LayerGraphData>),
      );

      expect(flowChart.onElementPressed, isNotNull);
    });

    testWidgets('onDashboardTapped callback is wired', (tester) async {
      final dashboard = createTestDashboard();
      await tester.pumpWidget(buildWidget(dashboard));

      final flowChart = tester.widget<FlowChart<LayerGraphData>>(
        find.byType(FlowChart<LayerGraphData>),
      );

      expect(flowChart.onDashboardTapped, isNotNull);
    });

    testWidgets('renders output type tag', (tester) async {
      final dashboard = createTestDashboard();
      await tester.pumpWidget(buildWidget(dashboard));
      await tester.pumpAndSettle();
      expect(find.text('json'), findsOneWidget);
    });

    testWidgets('renders with empty dashboard', (tester) async {
      final dashboard = Dashboard<LayerGraphData>(
        dataSerializer: DataSerializerImpl(),
      );
      await tester.pumpWidget(buildWidget(dashboard));
      expect(find.byType(FlowChart<LayerGraphData>), findsOneWidget);
    });

    testWidgets('renders disabled layer with reduced opacity', (tester) async {
      final dashboard = buildDashboard([
        const LayerDefinition(
          name: 'DisabledLayer',
          inputTypes: [],
          outputTypes: [],
          workerNames: [],
          enabled: false,
        ),
      ], []);
      await tester.pumpWidget(buildWidget(dashboard));
      await tester.pumpAndSettle();

      final opacity = tester.widget<Opacity>(find.byType(Opacity).first);
      expect(opacity.opacity, 0.5);
    });
  });
}
