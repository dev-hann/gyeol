import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gyeol/core/theme/app_theme.dart';
import 'package:gyeol/shared/widgets/empty_state.dart';

void main() {
  Widget buildWidget({Widget? action}) {
    return MaterialApp(
      home: Scaffold(
        body: EmptyState(
          icon: Icons.inbox,
          title: 'Nothing here',
          description: 'Add something to get started',
          action: action,
        ),
      ),
    );
  }

  group('EmptyState', () {
    testWidgets('renders icon', (tester) async {
      await tester.pumpWidget(buildWidget());
      expect(find.byIcon(Icons.inbox), findsOneWidget);
    });

    testWidgets('icon has size 48 and textMuted color', (tester) async {
      await tester.pumpWidget(buildWidget());
      final icon = tester.widget<Icon>(find.byIcon(Icons.inbox));
      expect(icon.size, 48);
      expect(icon.color, AppColors.textMuted);
    });

    testWidgets('renders title text', (tester) async {
      await tester.pumpWidget(buildWidget());
      expect(find.text('Nothing here'), findsOneWidget);
    });

    testWidgets('title has fontSize 16, w600, foreground color', (
      tester,
    ) async {
      await tester.pumpWidget(buildWidget());
      final title = tester.widget<Text>(find.text('Nothing here'));
      expect(title.style?.fontSize, 16);
      expect(title.style?.fontWeight, FontWeight.w600);
      expect(title.style?.color, AppColors.foreground);
    });

    testWidgets('renders description text', (tester) async {
      await tester.pumpWidget(buildWidget());
      expect(find.text('Add something to get started'), findsOneWidget);
    });

    testWidgets('description has fontSize 13, textSecondary, center align', (
      tester,
    ) async {
      await tester.pumpWidget(buildWidget());
      final desc = tester.widget<Text>(
        find.text('Add something to get started'),
      );
      expect(desc.style?.fontSize, 13);
      expect(desc.style?.color, AppColors.textSecondary);
      expect(desc.textAlign, TextAlign.center);
    });

    testWidgets('does not show action when null', (tester) async {
      await tester.pumpWidget(buildWidget());
      expect(find.byType(TextButton), findsNothing);
    });

    testWidgets('shows action widget when provided', (tester) async {
      await tester.pumpWidget(
        buildWidget(
          action: TextButton(onPressed: () {}, child: const Text('Add')),
        ),
      );
      expect(find.text('Add'), findsOneWidget);
    });

    testWidgets('Column has MainAxisSize.min', (tester) async {
      await tester.pumpWidget(buildWidget());
      final column = tester.widget<Column>(find.byType(Column));
      expect(column.mainAxisSize, MainAxisSize.min);
    });
  });
}
