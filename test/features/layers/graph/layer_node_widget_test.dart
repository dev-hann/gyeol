import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gyeol/core/theme/app_theme.dart';
import 'package:gyeol/features/layers/graph/layer_node_widget.dart';

void main() {
  Widget buildWidget(LayerNodeWidget widget) {
    return MaterialApp(home: Scaffold(body: widget));
  }

  const defaultWidget = LayerNodeWidget(
    name: 'TestLayer',
    enabled: true,
    workerCount: 3,
    outputTypes: ['text', 'summary'],
  );

  group('LayerNodeWidget', () {
    testWidgets('renders layer name', (tester) async {
      await tester.pumpWidget(buildWidget(defaultWidget));
      expect(find.text('TestLayer'), findsOneWidget);
    });

    testWidgets('renders worker count with plural', (tester) async {
      await tester.pumpWidget(buildWidget(defaultWidget));
      expect(find.text('3 workers'), findsOneWidget);
    });

    testWidgets('renders worker count with singular', (tester) async {
      await tester.pumpWidget(
        buildWidget(
          const LayerNodeWidget(
            name: 'Layer',
            enabled: true,
            workerCount: 1,
            outputTypes: [],
          ),
        ),
      );
      expect(find.text('1 worker'), findsOneWidget);
    });

    testWidgets('renders output type tags', (tester) async {
      await tester.pumpWidget(buildWidget(defaultWidget));
      expect(find.text('text'), findsOneWidget);
      expect(find.text('summary'), findsOneWidget);
    });

    testWidgets('shows memory icon for workers', (tester) async {
      await tester.pumpWidget(buildWidget(defaultWidget));
      expect(find.byIcon(Icons.memory), findsOneWidget);
    });

    testWidgets('enabled shows success status dot', (tester) async {
      await tester.pumpWidget(buildWidget(defaultWidget));
      final containers = tester.widgetList<Container>(find.byType(Container));
      final statusDot = containers.firstWhere((c) {
        final d = c.decoration as BoxDecoration?;
        return d?.shape == BoxShape.circle && d?.color == AppColors.success;
      });
      expect(statusDot, isNotNull);
    });

    testWidgets('disabled shows textMuted status dot and 0.5 opacity', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildWidget(
          const LayerNodeWidget(
            name: 'Disabled',
            enabled: false,
            workerCount: 0,
            outputTypes: [],
          ),
        ),
      );

      final opacity = tester.widget<Opacity>(find.byType(Opacity));
      expect(opacity.opacity, 0.5);

      final containers = tester.widgetList<Container>(find.byType(Container));
      final statusDot = containers.firstWhere((c) {
        final d = c.decoration as BoxDecoration?;
        return d?.shape == BoxShape.circle && d?.color == AppColors.textMuted;
      });
      expect(statusDot, isNotNull);
    });

    testWidgets('enabled uses primary border color', (tester) async {
      await tester.pumpWidget(buildWidget(defaultWidget));
      final containers = tester.widgetList<Container>(find.byType(Container));
      final nodeContainer = containers.firstWhere((c) {
        final d = c.decoration as BoxDecoration?;
        return d?.border is Border;
      });
      final decoration = nodeContainer.decoration! as BoxDecoration;
      final border = decoration.border! as Border;
      expect(border.top.color, AppColors.primary);
    });

    testWidgets('disabled uses textMuted border color', (tester) async {
      await tester.pumpWidget(
        buildWidget(
          const LayerNodeWidget(
            name: 'Disabled',
            enabled: false,
            workerCount: 0,
            outputTypes: [],
          ),
        ),
      );
      final containers = tester.widgetList<Container>(find.byType(Container));
      final nodeContainer = containers.firstWhere((c) {
        final d = c.decoration as BoxDecoration?;
        return d?.border is Border;
      });
      final decoration = nodeContainer.decoration! as BoxDecoration;
      final border = decoration.border! as Border;
      expect(border.top.color, AppColors.textMuted);
    });

    testWidgets('runningTasks > 0 shows CircularProgressIndicator', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildWidget(
          const LayerNodeWidget(
            name: 'Running',
            enabled: true,
            workerCount: 2,
            outputTypes: [],
            runningTasks: 3,
          ),
        ),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('runningTasks == 0 hides progress indicator', (tester) async {
      await tester.pumpWidget(buildWidget(defaultWidget));
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('limits output type tags to 3', (tester) async {
      await tester.pumpWidget(
        buildWidget(
          const LayerNodeWidget(
            name: 'Many',
            enabled: true,
            workerCount: 1,
            outputTypes: ['a', 'b', 'c', 'd', 'e'],
          ),
        ),
      );
      expect(find.text('a'), findsOneWidget);
      expect(find.text('b'), findsOneWidget);
      expect(find.text('c'), findsOneWidget);
      expect(find.text('d'), findsNothing);
      expect(find.text('e'), findsNothing);
    });

    testWidgets('empty outputTypes hides Wrap', (tester) async {
      await tester.pumpWidget(
        buildWidget(
          const LayerNodeWidget(
            name: 'Empty',
            enabled: true,
            workerCount: 0,
            outputTypes: [],
          ),
        ),
      );
      expect(find.byType(Wrap), findsNothing);
    });

    testWidgets('runningTasks > 0 adds box shadow', (tester) async {
      await tester.pumpWidget(
        buildWidget(
          const LayerNodeWidget(
            name: 'Shadow',
            enabled: true,
            workerCount: 1,
            outputTypes: [],
            runningTasks: 2,
          ),
        ),
      );
      final containers = tester.widgetList<Container>(find.byType(Container));
      final nodeContainer = containers.firstWhere((c) {
        final d = c.decoration as BoxDecoration?;
        return d?.boxShadow != null && d!.boxShadow!.isNotEmpty;
      });
      final decoration = nodeContainer.decoration! as BoxDecoration;
      expect(decoration.boxShadow, isNotEmpty);
      expect(
        decoration.boxShadow!.first.color,
        AppColors.info.withValues(alpha: 0.3),
      );
    });

    testWidgets('node has fixed size 240x120', (tester) async {
      await tester.pumpWidget(buildWidget(defaultWidget));
      final containers = tester.widgetList<Container>(find.byType(Container));
      final sized = containers.firstWhere(
        (c) =>
            c.constraints?.maxWidth == 240 && c.constraints?.maxHeight == 120,
      );
      expect(sized, isNotNull);
    });
  });
}
