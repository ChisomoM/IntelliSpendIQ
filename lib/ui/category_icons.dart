import 'package:flutter/material.dart';

/// The category icon registry.
///
/// Categories used to store an emoji glyph, and the category editor
/// asked the user to paste one. The brand guide bans emoji outright, so
/// the `icon` column now holds a **stable string key** from
/// [CategoryIcons.all] and rendering goes through [CategoryIcons.resolve].
///
/// Keys are stored rather than code points because [IconData] code
/// points are not a stable public contract across Flutter releases, and
/// a key survives export, backup and restore as readable text.
abstract final class CategoryIcons {
  /// The pickable set, in the order the picker shows them. Keys are
  /// written once here and never re-spelled at a call site.
  static const all = <String, IconData>{
    'food': Icons.restaurant_outlined,
    'groceries': Icons.local_grocery_store_outlined,
    'transport': Icons.directions_bus_outlined,
    'fuel': Icons.local_gas_station_outlined,
    'airtime': Icons.smartphone_outlined,
    'internet': Icons.wifi,
    'transfer': Icons.swap_horiz,
    'shopping': Icons.shopping_bag_outlined,
    'bills': Icons.receipt_long_outlined,
    'rent': Icons.home_outlined,
    'power': Icons.bolt_outlined,
    'water': Icons.water_drop_outlined,
    'health': Icons.medical_services_outlined,
    'education': Icons.school_outlined,
    'family': Icons.people_outline,
    'gifts': Icons.card_giftcard_outlined,
    'entertainment': Icons.sports_esports_outlined,
    'travel': Icons.flight_outlined,
    'savings': Icons.savings_outlined,
    'income': Icons.payments_outlined,
    'business': Icons.storefront_outlined,
    'fees': Icons.account_balance_outlined,
    'church': Icons.volunteer_activism_outlined,
    'pets': Icons.pets_outlined,
    'clothing': Icons.checkroom_outlined,
    'repairs': Icons.build_outlined,
    'other': Icons.category_outlined,
    'unknown': Icons.help_outline,
  };

  /// What an unrecognised or absent key falls back to.
  static const IconData fallback = Icons.category_outlined;

  /// Emoji that shipped as seed data before this registry existed.
  ///
  /// Kept as a render-time safety net so a database written by an older
  /// build — or restored from an old backup, which the migration never
  /// sees — still shows a sensible icon rather than the fallback.
  static const _legacyEmoji = <String, String>{
    '🍲': 'food',
    '🚌': 'transport',
    '📱': 'airtime',
    '🔁': 'transfer',
    '🛍️': 'shopping',
    '🛍': 'shopping',
    '🧾': 'bills',
    '💰': 'income',
    '🏦': 'fees',
    '❓': 'unknown',
    '📦': 'other',
  };

  /// Resolves a stored value to an icon, accepting a current key, a
  /// legacy emoji, or null.
  static IconData resolve(String? stored) {
    if (stored == null || stored.isEmpty) return fallback;
    final byKey = all[stored];
    if (byKey != null) return byKey;
    final legacy = _legacyEmoji[stored];
    if (legacy != null) return all[legacy] ?? fallback;
    return fallback;
  }

  /// The key a legacy emoji maps to, or null if it is not one we seeded.
  /// Drives the one-off database migration.
  static String? keyForLegacyEmoji(String emoji) => _legacyEmoji[emoji];

  /// Every legacy emoji → key pair, for the migration to iterate.
  static Map<String, String> get legacyPairs => Map.unmodifiable(_legacyEmoji);
}

/// Picks a category icon from [CategoryIcons.all].
///
/// Replaces the old free-text field that asked the user to *"Paste an
/// emoji"* — which produced an inconsistent icon set, rendered
/// differently on every Android version, and read as a different product
/// on every row.
class CategoryIconPicker extends StatelessWidget {
  const CategoryIconPicker({
    required this.selectedKey,
    required this.onSelected,
    super.key,
  });

  final String? selectedKey;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final entries = CategoryIcons.all.entries.toList();

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        // 56 keeps every target above the 48dp floor at any width.
        maxCrossAxisExtent: 56,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
      ),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        final isSelected = entry.key == selectedKey;

        return Semantics(
          selected: isSelected,
          button: true,
          label: entry.key,
          child: InkWell(
            onTap: () => onSelected(entry.key),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              decoration: BoxDecoration(
                color: isSelected
                    ? scheme.secondaryContainer
                    : scheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(12),
                border: isSelected
                    ? Border.all(color: scheme.secondary, width: 2)
                    : null,
              ),
              child: Icon(
                entry.value,
                size: 22,
                color: isSelected ? scheme.secondary : scheme.onSurfaceVariant,
              ),
            ),
          ),
        );
      },
    );
  }
}
