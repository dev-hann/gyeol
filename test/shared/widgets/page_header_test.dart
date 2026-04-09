import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gyeol/core/theme/app_theme.dart';
import 'package:gyeol/shared/widgets/page_header.dart';

void main() {
  Widget buildWidget({Widget? action}) {
    return MaterialApp(
      home: Scaffold(
        body: PageHeader(
          icon: Icons.settings,
          title: 'Settings',
          description: 'Configure your workspace',
          action: action,
        ),
      ),
    );
  }

  group('PageHeader', () {
    testWidgets('renders title text', (tester) async {
      await tester.pumpWidget(buildWidget());
      expect(find.text('Settings'), findsOneWidget);
    });

    testWidgets('renders description text', (tester) async {
      await tester.pumpWidget(buildWidget());
      expect(find.text('Configure your workspace'), findsOneWidget);
    });

    testWidgets('renders icon', (tester) async {
      await tester.pumpWidget(buildWidget());
      expect(find.byIcon(Icons.settings), findsOneWidget);
    });

    testWidgets('icon has primary color and size 18', (tester) async {
      await tester.pumpWidget(buildWidget());
      final icon = tester.widget<Icon>(find.byIcon(Icons.settings));
      expect(icon.color, AppColors.primary);
      expect(icon.size, 18);
    });

    testWidgets('icon container has primary color with alpha 0.1', (
      tester,
    ) async {
      await tester.pumpWidget(buildWidget());
      final containers = tester.widgetList<Container>(
        find.ancestor(
          of: find.byIcon(Icons.settings),
          matching: find.byType(Container),
        ),
      );
      final iconContainer = containers.first;
      final decoration = iconContainer.decoration as BoxDecoration?;
      expect(decoration, isNotNull);
      expect(decoration!.color, AppColors.primary.withValues(alpha: 0.1));
      expect(decoration.borderRadius, BorderRadius.circular(8));
    });

    testWidgets('icon container is 36x36', (tester) async {
      await tester.pumpWidget(buildWidget());
      final container = tester
          .widgetList<Container>(
            find.ancestor(
              of: find.byIcon(Icons.settings),
              matching: find.byType(Container),
            ),
          )
          .first;
      final constraints = container.constraints;
      expect(constraints?.maxWidth, 36);
      expect(constraints?.maxHeight, 36);
    });

    testWidgets('title has fontSize 20 and w600 weight', (tester) async {
      await tester.pumpWidget(buildWidget());
      final title = tester.widget<Text>(find.text('Settings'));
      expect(title.style?.fontSize, 20);
      expect(title.style?.fontWeight, FontWeight.w600);
      expect(title.style?.color, AppColors.foreground);
    });

    testWidgets('description has fontSize 13 and textSecondary color', (
      tester,
    ) async {
      await tester.pumpWidget(buildWidget());
      final desc = tester.widget<Text>(find.text('Configure your workspace'));
      expect(desc.style?.fontSize, 13);
      expect(desc.style?.color, AppColors.textSecondary);
    });

    testWidgets('does not show action when null', (tester) async {
      await tester.pumpWidget(buildWidget());
      expect(find.byType(TextButton), findsNothing);
    });

    testWidgets('shows action widget when provided', (tester) async {
      await tester.pumpWidget(
        buildWidget(
          action: TextButton(onPressed: () {}, child: const Text('Action')),
        ),
      );
      expect(find.text('Action'), findsOneWidget);
    });

    testWidgets('layout is Row with icon, text column, and optional action', (
      tester,
    ) async {
      await tester.pumpWidget(buildWidget());
      expect(find.byType(Row), findsOneWidget);
      expect(find.byType(Column), findsOneWidget);
    });
  });
}
