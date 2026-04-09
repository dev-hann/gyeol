import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gyeol/core/theme/app_theme.dart';
import 'package:gyeol/shared/widgets/status_badge.dart';

void main() {
  Widget buildWidget(StatusBadge badge) {
    return MaterialApp(home: Scaffold(body: badge));
  }

  group('StatusBadge', () {
    testWidgets('renders status text', (tester) async {
      await tester.pumpWidget(
        buildWidget(const StatusBadge(status: 'running')),
      );

      expect(find.text('running'), findsOneWidget);
    });

    testWidgets('renders with custom fontSize', (tester) async {
      await tester.pumpWidget(
        buildWidget(const StatusBadge(status: 'done', fontSize: 14)),
      );

      final text = tester.widget<Text>(find.text('done'));
      expect(text.style?.fontSize, 14);
    });

    testWidgets('defaults fontSize to 11', (tester) async {
      await tester.pumpWidget(
        buildWidget(const StatusBadge(status: 'pending')),
      );

      final text = tester.widget<Text>(find.text('pending'));
      expect(text.style?.fontSize, 11);
    });

    testWidgets('uses info color for running', (tester) async {
      await tester.pumpWidget(
        buildWidget(const StatusBadge(status: 'running')),
      );

      final text = tester.widget<Text>(find.text('running'));
      expect(text.style?.color, AppColors.info);
    });

    testWidgets('uses success color for done', (tester) async {
      await tester.pumpWidget(buildWidget(const StatusBadge(status: 'done')));

      final text = tester.widget<Text>(find.text('done'));
      expect(text.style?.color, AppColors.success);
    });

    testWidgets('uses success color for success', (tester) async {
      await tester.pumpWidget(
        buildWidget(const StatusBadge(status: 'success')),
      );

      final text = tester.widget<Text>(find.text('success'));
      expect(text.style?.color, AppColors.success);
    });

    testWidgets('uses error color for failed', (tester) async {
      await tester.pumpWidget(buildWidget(const StatusBadge(status: 'failed')));

      final text = tester.widget<Text>(find.text('failed'));
      expect(text.style?.color, AppColors.error);
    });

    testWidgets('uses error color for error', (tester) async {
      await tester.pumpWidget(buildWidget(const StatusBadge(status: 'error')));

      final text = tester.widget<Text>(find.text('error'));
      expect(text.style?.color, AppColors.error);
    });

    testWidgets('uses warning color for pending', (tester) async {
      await tester.pumpWidget(
        buildWidget(const StatusBadge(status: 'pending')),
      );

      final text = tester.widget<Text>(find.text('pending'));
      expect(text.style?.color, AppColors.warning);
    });

    testWidgets('uses warning color for warning', (tester) async {
      await tester.pumpWidget(
        buildWidget(const StatusBadge(status: 'warning')),
      );

      final text = tester.widget<Text>(find.text('warning'));
      expect(text.style?.color, AppColors.warning);
    });

    testWidgets('uses textMuted for unknown status', (tester) async {
      await tester.pumpWidget(
        buildWidget(const StatusBadge(status: 'unknown')),
      );

      final text = tester.widget<Text>(find.text('unknown'));
      expect(text.style?.color, AppColors.textMuted);
    });

    testWidgets('uses textMuted for idle', (tester) async {
      await tester.pumpWidget(buildWidget(const StatusBadge(status: 'idle')));

      final text = tester.widget<Text>(find.text('idle'));
      expect(text.style?.color, AppColors.textMuted);
    });

    testWidgets('has rounded container with border', (tester) async {
      await tester.pumpWidget(
        buildWidget(const StatusBadge(status: 'running')),
      );

      final container = tester.widget<Container>(
        find.ancestor(
          of: find.text('running'),
          matching: find.byType(Container),
        ),
      );
      final boxDecoration = container.decoration as BoxDecoration?;
      expect(boxDecoration, isNotNull);
      expect(boxDecoration!.borderRadius, BorderRadius.circular(6));
      expect(boxDecoration.border, isA<Border>());
    });

    testWidgets('fontWeight is w600', (tester) async {
      await tester.pumpWidget(buildWidget(const StatusBadge(status: 'done')));

      final text = tester.widget<Text>(find.text('done'));
      expect(text.style?.fontWeight, FontWeight.w600);
    });

    testWidgets('is case insensitive', (tester) async {
      await tester.pumpWidget(
        buildWidget(const StatusBadge(status: 'Running')),
      );

      final text = tester.widget<Text>(find.text('Running'));
      expect(text.style?.color, AppColors.info);
    });
  });
}
