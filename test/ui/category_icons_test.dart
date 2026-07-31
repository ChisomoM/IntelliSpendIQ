import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intellispendiq/data/repositories/category_repository.dart';
import 'package:intellispendiq/ui/category_icons.dart';

void main() {
  group('CategoryIcons.resolve', () {
    test('resolves a current key', () {
      expect(CategoryIcons.resolve('food'), Icons.restaurant_outlined);
      expect(CategoryIcons.resolve('transport'), Icons.directions_bus_outlined);
    });

    test('still resolves a legacy emoji written by an older build', () {
      // A database restored from an old backup never sees the v8
      // migration, so rendering has to cope with the emoji itself.
      expect(CategoryIcons.resolve('🍲'), Icons.restaurant_outlined);
      expect(CategoryIcons.resolve('🚌'), Icons.directions_bus_outlined);
      expect(CategoryIcons.resolve('💰'), Icons.payments_outlined);
    });

    test('falls back rather than throwing on an unknown value', () {
      // A user who pasted their own emoji into the old free-text field
      // has a value nothing can map — it must still render something.
      expect(CategoryIcons.resolve('🎮'), CategoryIcons.fallback);
      expect(CategoryIcons.resolve('not-a-key'), CategoryIcons.fallback);
      expect(CategoryIcons.resolve(''), CategoryIcons.fallback);
      expect(CategoryIcons.resolve(null), CategoryIcons.fallback);
    });
  });

  group('seed categories', () {
    test('carry icon keys, never emoji', () {
      for (final seed in CategoryRepository.seedNames) {
        expect(
          CategoryIcons.all.containsKey(seed.$2),
          isTrue,
          reason:
              '"${seed.$1}" seeds icon "${seed.$2}", which is not a '
              'registry key — the brand guide bans emoji, so every seed '
              'must name an icon.',
        );
      }
    });

    test('every legacy emoji maps to a key that still exists', () {
      for (final entry in CategoryIcons.legacyPairs.entries) {
        expect(
          CategoryIcons.all.containsKey(entry.value),
          isTrue,
          reason:
              '${entry.key} maps to "${entry.value}", which was removed '
              'from the registry — that would silently downgrade an '
              'existing user to the fallback icon.',
        );
      }
    });
  });
}
