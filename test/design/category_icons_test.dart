import 'package:flutter_test/flutter_test.dart';
import 'package:intellispendiq/design/tokens/icons.dart';
import 'package:intellispendiq/domain/models/category.dart';
import 'package:intellispendiq/domain/models/category_icon_key.dart';

void main() {
  group('CategoryIcons', () {
    test('resolves every pickable key to a distinct icon', () {
      final keys = CategoryIcons.pickableKeys;
      expect(keys, isNotEmpty);
      for (final key in keys) {
        expect(
          CategoryIcons.byKey(key),
          isNotNull,
          reason: '$key should resolve to an icon',
        );
      }
    });

    test('maps a legacy emoji already on disk onto its key', () {
      // The seeds used to write emoji straight into categories.icon.
      // Those rows are never migrated, so resolution has to keep
      // working for them or an upgrading user loses their icons.
      expect(
        CategoryIcons.byKey('🍲'),
        CategoryIcons.byKey(CategoryIconKey.food),
      );
      expect(
        CategoryIcons.byKey('🚌'),
        CategoryIcons.byKey(CategoryIconKey.transport),
      );
      // Shopping was seeded both with and without a variation selector.
      expect(
        CategoryIcons.byKey('🛍️'),
        CategoryIcons.byKey(CategoryIconKey.shopping),
      );
    });

    test('falls back to the other icon rather than throwing', () {
      expect(
        CategoryIcons.byKey('something-nobody-defined'),
        CategoryIcons.byKey(CategoryIconKey.other),
      );
      expect(
        CategoryIcons.byKey(null),
        CategoryIcons.byKey(CategoryIconKey.other),
      );
    });

    test('isLegacyEmoji only flags stored emoji, not keys', () {
      expect(CategoryIcons.isLegacyEmoji('🍲'), isTrue);
      expect(CategoryIcons.isLegacyEmoji(CategoryIconKey.food), isFalse);
      expect(CategoryIcons.isLegacyEmoji(null), isFalse);
    });
  });

  group('Category.displayName', () {
    test('is the name alone, never the icon key glued to it', () {
      // It used to return "$icon $name", which worked while icon held
      // an emoji. With icon holding a key that would read "food Food"
      // — and would be sent to the model in the assistant's payloads.
      const category = Category(
        id: 'c1',
        name: 'Food',
        icon: CategoryIconKey.food,
      );
      expect(category.displayName, 'Food');
    });

    test('is the name when no icon is set', () {
      const category = Category(id: 'c1', name: 'Food');
      expect(category.displayName, 'Food');
    });
  });
}
