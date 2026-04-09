import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gyeol/core/theme/app_theme.dart';

void main() {
  group('AppColors', () {
    test('background is correct value', () {
      expect(AppColors.background, const Color(0xFF0f0f11));
    });

    test('card is correct value', () {
      expect(AppColors.card, const Color(0xFF18181b));
    });

    test('tertiary is correct value', () {
      expect(AppColors.tertiary, const Color(0xFF1e1e22));
    });

    test('foreground is correct value', () {
      expect(AppColors.foreground, const Color(0xFFfafafa));
    });

    test('primary is correct value', () {
      expect(AppColors.primary, const Color(0xFF6d5acf));
    });

    test('error is correct value', () {
      expect(AppColors.error, const Color(0xFFef4444));
    });

    test('success is correct value', () {
      expect(AppColors.success, const Color(0xFF22c55e));
    });

    test('warning is correct value', () {
      expect(AppColors.warning, const Color(0xFFf59e0b));
    });

    test('info is correct value', () {
      expect(AppColors.info, const Color(0xFF3b82f6));
    });

    test('all color constants are const Color', () {
      const colors = <Color>[
        AppColors.background,
        AppColors.card,
        AppColors.tertiary,
        AppColors.hover,
        AppColors.foreground,
        AppColors.textSecondary,
        AppColors.textMuted,
        AppColors.primary,
        AppColors.primaryForeground,
        AppColors.primaryHover,
        AppColors.border,
        AppColors.success,
        AppColors.warning,
        AppColors.error,
        AppColors.info,
      ];
      expect(colors.length, 15);
      expect(colors.toSet().length, 14);
    });
  });

  group('buildAppTheme', () {
    late ThemeData theme;

    setUp(() {
      theme = buildAppTheme();
    });

    test('returns dark brightness', () {
      expect(theme.brightness, Brightness.dark);
    });

    test('scaffoldBackgroundColor is AppColors.background', () {
      expect(theme.scaffoldBackgroundColor, AppColors.background);
    });

    test('cardColor is AppColors.card', () {
      expect(theme.cardColor, AppColors.card);
    });

    test('colorScheme primary is AppColors.primary', () {
      expect(theme.colorScheme.primary, AppColors.primary);
    });

    test('colorScheme error is AppColors.error', () {
      expect(theme.colorScheme.error, AppColors.error);
    });

    test('colorScheme surface is AppColors.card', () {
      expect(theme.colorScheme.surface, AppColors.card);
    });

    test('appBarTheme has zero elevation', () {
      expect(theme.appBarTheme.elevation, 0);
    });

    test('dividerTheme color is AppColors.border', () {
      expect(theme.dividerTheme.color, AppColors.border);
    });

    test('iconTheme color is AppColors.textSecondary', () {
      expect(theme.iconTheme.color, AppColors.textSecondary);
    });

    test('inputDecorationTheme is filled', () {
      expect(theme.inputDecorationTheme.filled, true);
    });

    test('inputDecorationTheme fillColor is AppColors.tertiary', () {
      expect(theme.inputDecorationTheme.fillColor, AppColors.tertiary);
    });
  });
}
