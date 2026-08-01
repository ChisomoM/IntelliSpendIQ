import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intellispendiq/design/tokens/category_palette.dart';
import 'package:intellispendiq/design/tokens/colors.dart';

/// WCAG relative luminance.
double _luminance(Color c) {
  double channel(double v) {
    final s = v;
    return s <= 0.03928 ? s / 12.92 : math.pow((s + 0.055) / 1.055, 2.4) as double;
  }

  return 0.2126 * channel(c.r) +
      0.7152 * channel(c.g) +
      0.0722 * channel(c.b);
}

double _contrast(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  final hi = math.max(la, lb);
  final lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  group('CategoryPalette', () {
    test('every glyph is legible on its own chip, in both modes', () {
      // The values were produced by the data-viz validator; this test
      // is the guard that stops someone hand-editing one of them back
      // below the floor.
      for (final brightness in Brightness.values) {
        for (final hue in CategoryPalette.of(brightness)) {
          expect(
            _contrast(hue.ink, hue.tint),
            greaterThanOrEqualTo(4.5),
            reason: '${hue.name} ink on tint (${brightness.name})',
          );
        }
      }
    });

    test('series colours clear 3:1 on the surface they are drawn on', () {
      for (final hue in CategoryPalette.of(Brightness.dark)) {
        expect(
          _contrast(hue.series, AppColors.night800),
          greaterThanOrEqualTo(3.0),
          reason: '${hue.name} series on night800',
        );
      }
    });

    test('excludes the hues that already mean something else', () {
      final names = CategoryPalette.of(
        Brightness.light,
      ).map((h) => h.name).toList();
      // Green and red belong to money direction, violet to actions —
      // a category wearing any of them would argue with the ledger or
      // impersonate a button.
      expect(names, isNot(contains('green')));
      expect(names, isNot(contains('red')));
      expect(names, isNot(contains('violet')));
    });

    test('a category keeps its hue regardless of rank or neighbours', () {
      const id = 'category-abc';
      final first = CategoryPalette.forCategory(
        categoryId: id,
        brightness: Brightness.light,
      );
      final again = CategoryPalette.forCategory(
        categoryId: id,
        brightness: Brightness.light,
      );
      expect(first.name, again.name);
      // Two different ids must not be forced apart, but the same id
      // must never drift — that is the property that matters.
      expect(
        CategoryPalette.slotFor(id),
        CategoryPalette.slotFor(id),
      );
    });

    test('a pinned colour wins over the derived one', () {
      final derived = CategoryPalette.forCategory(
        categoryId: 'x',
        brightness: Brightness.light,
      );
      final pinned = CategoryPalette.forCategory(
        categoryId: 'x',
        storedColor: 'aqua',
        brightness: Brightness.light,
      );
      expect(pinned.name, 'aqua');
      expect(pinned.name, isNot(derived.name));
    });

    test('an unknown stored colour falls back rather than throwing', () {
      final hue = CategoryPalette.forCategory(
        categoryId: 'x',
        storedColor: 'chartreuse',
        brightness: Brightness.light,
      );
      expect(hue.name, CategoryPalette.forCategory(
        categoryId: 'x',
        brightness: Brightness.light,
      ).name);
    });

    test('the sequential ramp runs one hue, never a spread', () {
      // Monotonic in luminance is what makes "more" readable as "more".
      for (final brightness in Brightness.values) {
        final steps = [
          for (var i = 0; i <= 10; i++)
            CategoryPalette.sequential(i / 10, brightness),
        ];
        final luminances = steps.map(_luminance).toList();
        final ascending = luminances.first < luminances.last;
        for (var i = 1; i < luminances.length; i++) {
          expect(
            ascending
                ? luminances[i] >= luminances[i - 1]
                : luminances[i] <= luminances[i - 1],
            isTrue,
            reason: 'ramp reverses at step $i (${brightness.name})',
          );
        }
      }
    });
  });
}
