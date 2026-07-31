import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intellispendiq/app/theme/money_colors.dart';
import 'package:intellispendiq/app/theme/theme.dart';
import 'package:intellispendiq/app/theme/tokens.dart';
import 'package:intellispendiq/app/theme/typography.dart';

/// WCAG relative luminance.
double _luminance(Color c) {
  double channel(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
}

/// WCAG contrast ratio between two opaque colours.
double _contrast(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  final (lighter, darker) = la > lb ? (la, lb) : (lb, la);
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  final light = AppTheme.light;
  final dark = AppTheme.dark;

  group('contrast sweep', () {
    test('body and metadata text clear 4.5:1 on their own surface', () {
      expect(
        _contrast(AppColors.ink900, AppColors.paper),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrast(AppColors.ink400, AppColors.paper),
        greaterThanOrEqualTo(4.5),
        reason: 'ink400 is the light-mode text floor',
      );
      expect(
        _contrast(AppColors.nightText, AppColors.night900),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrast(AppColors.nightText2, AppColors.night900),
        greaterThanOrEqualTo(4.5),
        reason: 'nightText2 is the dark-mode text floor',
      );
    });

    test('load-bearing borders clear the 3:1 non-text floor', () {
      expect(
        _contrast(AppColors.ink300, AppColors.paper),
        greaterThanOrEqualTo(3.0),
      );
      expect(
        _contrast(AppColors.nightLineStrong, AppColors.night800),
        greaterThanOrEqualTo(3.0),
        reason: 'input outlines sit on a card in dark mode',
      );
    });

    test('button labels clear 4.5:1 against their own fill', () {
      expect(
        _contrast(AppColors.paper, AppColors.violet600),
        greaterThanOrEqualTo(4.5),
        reason: 'white label on the light-mode primary',
      );
      expect(
        _contrast(AppColors.ink900, AppColors.cyan300),
        greaterThanOrEqualTo(4.5),
        reason: 'ink label on the dark-mode primary',
      );
      expect(
        _contrast(AppColors.violet700, AppColors.paper),
        greaterThanOrEqualTo(4.5),
        reason: 'links and the focus ring in light mode',
      );
    });

    test('money colours are legible on the surface they render on', () {
      for (final c in [
        AppColors.inflowLight,
        AppColors.outflowLight,
        AppColors.reviewLight,
      ]) {
        expect(_contrast(c, AppColors.paper), greaterThanOrEqualTo(4.5));
      }
      for (final c in [
        AppColors.inflowDark,
        AppColors.outflowDark,
        AppColors.reviewDark,
      ]) {
        expect(_contrast(c, AppColors.night900), greaterThanOrEqualTo(4.5));
      }
    });

    test('cyan300 and violet300 are never usable on a light surface', () {
      // The guide's hardest colour rule, and the reason neither appears
      // anywhere in the light ColorScheme: both land far below the text
      // floor on white, with no size or weight exception.
      expect(_contrast(AppColors.cyan300, AppColors.paper), lessThan(3.0));
      expect(_contrast(AppColors.violet300, AppColors.paper), lessThan(3.0));

      final scheme = light.colorScheme;
      for (final used in [
        scheme.primary,
        scheme.secondary,
        scheme.onSurface,
        scheme.onSurfaceVariant,
        scheme.onPrimary,
      ]) {
        expect(
          used,
          isNot(anyOf(AppColors.cyan300, AppColors.violet300)),
          reason: 'a light-mode role resolved to a dark-only accent',
        );
      }
    });
  });

  group('brand colours are fixed', () {
    test('light primary is violet, dark primary is cyan', () {
      expect(light.colorScheme.primary, AppColors.violet600);
      expect(light.colorScheme.onPrimary, AppColors.paper);
      expect(dark.colorScheme.primary, AppColors.cyan300);
      expect(dark.colorScheme.onPrimary, AppColors.ink900);
    });

    test('both brightnesses carry the money palette', () {
      expect(light.extension<MoneyColors>(), MoneyColors.light);
      expect(dark.extension<MoneyColors>(), MoneyColors.dark);
    });
  });

  group('dark mode has no shadows', () {
    test('elevation is surface lightness, not a shadow', () {
      expect(dark.cardTheme.elevation, 0);
      expect(dark.appBarTheme.elevation, 0);
      expect(dark.bottomSheetTheme.elevation, 0);
      expect(dark.bottomSheetTheme.modalElevation, 0);
      expect(dark.dialogTheme.elevation, 0);
      expect(dark.floatingActionButtonTheme.elevation, 0);
      expect(dark.snackBarTheme.elevation, 0);
    });

    test('cards sit a step lighter than the page behind them', () {
      expect(dark.scaffoldBackgroundColor, AppColors.night900);
      expect(dark.cardTheme.color, AppColors.night800);
      expect(dark.bottomSheetTheme.backgroundColor, AppColors.night700);
      expect(
        _luminance(AppColors.night800),
        greaterThan(_luminance(AppColors.night900)),
      );
      expect(
        _luminance(AppColors.night700),
        greaterThan(_luminance(AppColors.night800)),
      );
    });
  });

  group('typography', () {
    test('interface type is IBM Plex Sans', () {
      expect(light.textTheme.bodyMedium?.fontFamily, AppFonts.sans);
      expect(light.textTheme.titleMedium?.fontFamily, AppFonts.sans);
    });

    test('every numeric style is mono and tabular', () {
      for (final style in [
        AppText.balance,
        AppText.amountLarge,
        AppText.amount,
        AppText.amountSmall,
      ]) {
        expect(style.fontFamily, AppFonts.mono);
        expect(
          style.fontFeatures,
          contains(const FontFeature.tabularFigures()),
          reason: 'a column of amounts has to align on the decimal',
        );
      }
    });

    test('13px is the floor, and the 11px overline is the exception', () {
      expect(AppText.metadata.fontSize, 13);
      expect(AppText.overline.fontSize, 11);
      expect(
        AppText.overline.letterSpacing,
        greaterThan(0),
        reason: 'the 11px exception is only allowed tracked and uppercase',
      );
    });
  });

  group('shape and touch targets', () {
    test('the FAB is a rounded rectangle, not a circle', () {
      final shape = light.floatingActionButtonTheme.shape;
      expect(shape, isA<RoundedRectangleBorder>());
      expect(
        (shape! as RoundedRectangleBorder).borderRadius,
        BorderRadius.circular(Radii.fab),
      );
    });

    test('buttons are at least 48dp tall', () {
      for (final size in [
        light.filledButtonTheme.style?.minimumSize?.resolve({}),
        light.outlinedButtonTheme.style?.minimumSize?.resolve({}),
        light.textButtonTheme.style?.minimumSize?.resolve({}),
      ]) {
        expect(size?.height, greaterThanOrEqualTo(48));
      }
    });
  });
}
