import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gyeol/core/theme/app_theme.dart';
import 'package:gyeol/shared/widgets/stat_card.dart';

void main() {
  Widget buildWidget(StatCard card) {
    return MaterialApp(home: Scaffold(body: card));
  }

  const testColor = AppColors.info;

  group('StatCard', () {
    testWidgets('renders label uppercased', (tester) async {
      await tester.pumpWidget(
        buildWidget(
          const StatCard(
            label: 'tasks',
            value: '5',
            icon: Icons.task,
            color: testColor,
          ),
        ),
      );

      expect(find.text('TASKS'), findsOneWidget);
    });

    testWidgets('renders value', (tester) async {
      await tester.pumpWidget(
        buildWidget(
          const StatCard(
            label: 'tasks',
            value: '42',
            icon: Icons.task,
            color: testColor,
          ),
        ),
      );

      expect(find.text('42'), findsOneWidget);
    });

    testWidgets('renders icon', (tester) async {
      await tester.pumpWidget(
        buildWidget(
          const StatCard(
            label: 'tasks',
            value: '5',
            icon: Icons.task,
            color: testColor,
          ),
        ),
      );

      expect(find.byIcon(Icons.task), findsOneWidget);
    });

    testWidgets('label uses textMuted color and fontSize 11', (tester) async {
      await tester.pumpWidget(
        buildWidget(
          const StatCard(
            label: 'tasks',
            value: '5',
            icon: Icons.task,
            color: testColor,
          ),
        ),
      );

      final label = tester.widget<Text>(find.text('TASKS'));
      expect(label.style?.color, AppColors.textMuted);
      expect(label.style?.fontSize, 11);
      expect(label.style?.letterSpacing, 0.5);
    });

    testWidgets('label icon uses textSecondary color', (tester) async {
      await tester.pumpWidget(
        buildWidget(
          const StatCard(
            label: 'tasks',
            value: '5',
            icon: Icons.task,
            color: testColor,
          ),
        ),
      );

      final icon = tester.widget<Icon>(find.byIcon(Icons.task));
      expect(icon.color, AppColors.textSecondary);
      expect(icon.size, 16);
    });

    testWidgets('value uses provided color and bold weight', (tester) async {
      await tester.pumpWidget(
        buildWidget(
          const StatCard(
            label: 'tasks',
            value: '99',
            icon: Icons.task,
            color: testColor,
          ),
        ),
      );

      final value = tester.widget<Text>(find.text('99'));
      expect(value.style?.color, testColor);
      expect(value.style?.fontWeight, FontWeight.bold);
      expect(value.style?.fontSize, 20);
    });

    testWidgets('value container has color with alpha 0.15', (tester) async {
      await tester.pumpWidget(
        buildWidget(
          const StatCard(
            label: 'tasks',
            value: '5',
            icon: Icons.task,
            color: testColor,
          ),
        ),
      );

      final containers = tester.widgetList<Container>(
        find.ancestor(of: find.text('5'), matching: find.byType(Container)),
      );

      final innerContainer = containers.first;
      final decoration = innerContainer.decoration as BoxDecoration?;
      expect(decoration, isNotNull);
      expect(decoration!.color, testColor.withValues(alpha: 0.15));
      expect(decoration.borderRadius, BorderRadius.circular(6));
    });

    testWidgets('wraps in Card', (tester) async {
      await tester.pumpWidget(
        buildWidget(
          const StatCard(
            label: 'tasks',
            value: '5',
            icon: Icons.task,
            color: testColor,
          ),
        ),
      );

      expect(find.byType(Card), findsOneWidget);
    });

    testWidgets('has 16px padding inside card', (tester) async {
      await tester.pumpWidget(
        buildWidget(
          const StatCard(
            label: 'tasks',
            value: '5',
            icon: Icons.task,
            color: testColor,
          ),
        ),
      );

      final paddings = tester.widgetList<Padding>(
        find.descendant(of: find.byType(Card), matching: find.byType(Padding)),
      );
      expect(
        paddings.any((p) => p.padding == const EdgeInsets.all(16)),
        isTrue,
      );
    });
  });
}
