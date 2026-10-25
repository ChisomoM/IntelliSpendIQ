import 'package:flutter/material.dart';
import 'package:intellispendiq/core/money.dart';
import 'package:intellispendiq/design/design.dart';
import 'package:intellispendiq/domain/models/category.dart';
import 'package:intellispendiq/domain/services/shopping_trip_calculator.dart';
import 'package:intellispendiq/shopping/cubit/cubit.dart';

/// One chip per category on the trip: how much room it has left, with
/// the words first and a thin meter behind them. Tapping narrows the
/// list below to that category.
class CategoryStrip extends StatelessWidget {
  const CategoryStrip({
    required this.lines,
    required this.categoriesById,
    required this.selectedKey,
    required this.onSelected,
    super.key,
  });

  final List<TripCategoryLine> lines;
  final Map<String, Category> categoriesById;

  /// The category the list is narrowed to, or null for all.
  final String? selectedKey;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    // Sized by its tallest chip rather than a fixed height, so larger
    // text settings grow the strip instead of overflowing it.
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final line in lines) ...[
              _LineChip(
                line: line,
                category: line.categoryId == null
                    ? null
                    : categoriesById[line.categoryId],
                selected:
                    selectedKey ==
                    (line.categoryId ?? ShoppingTripState.noCategoryKey),
                onTap: () => onSelected(
                  line.categoryId ?? ShoppingTripState.noCategoryKey,
                ),
              ),
              const SizedBox(width: Space.x1),
            ],
          ],
        ),
      ),
    );
  }
}

class _LineChip extends StatelessWidget {
  const _LineChip({
    required this.line,
    required this.category,
    required this.selected,
    required this.onTap,
  });

  final TripCategoryLine line;
  final Category? category;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final money = Theme.of(context).extension<MoneyColors>()!;

    final status = !line.hasBudget
        ? 'No budget'
        : line.isOver
        ? '${Money.display(line.overByMinor)} over'
        : '${Money.display(line.leftMinor!)} left';
    final statusColor = line.isOver ? money.outflow : colors.onSurface;

    return Semantics(
      button: true,
      selected: selected,
      label: '${category?.displayName ?? 'No category'}, $status',
      child: Material(
        color: colors.surface,
        borderRadius: BorderRadius.circular(Radii.card),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            width: 156,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(Radii.card),
              border: Border.all(
                color: selected ? colors.primary : colors.outlineVariant,
                width: selected ? 2 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (category != null)
                      CategoryAvatar(
                        iconKey: category!.icon,
                        categoryId: category!.id,
                        colorName: category!.color,
                        size: 24,
                      )
                    else
                      AppIcon(
                        AppIcons.unknown,
                        size: 20,
                        color: colors.onSurfaceVariant,
                      ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        category?.displayName ?? 'No category',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.rowTitle(color: colors.onSurface),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  status,
                  style: AppTypography.rowTitle(color: statusColor),
                ),
                const SizedBox(height: 2),
                Text(
                  line.onList ? 'On your list' : 'Not on your list',
                  style: AppTypography.metadata(color: colors.onSurfaceVariant),
                ),
                const SizedBox(height: 8),
                if (line.hasBudget)
                  ProgressMeter(
                    value: line.usedRatio,
                    isOver: line.isOver,
                    height: 4,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
