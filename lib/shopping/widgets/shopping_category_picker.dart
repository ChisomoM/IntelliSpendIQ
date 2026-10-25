import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intellispendiq/categories/categories.dart';
import 'package:intellispendiq/design/design.dart';
import 'package:intellispendiq/domain/models/category.dart';

/// Opens the shared category sheet over the expense categories and
/// returns the choice, or null if it was dismissed. A returned
/// [CategoryPick] with a null id means "no category".
Future<CategoryPick?> pickShoppingCategory(
  BuildContext context, {
  required Iterable<Category> categories,
  required String? selectedId,
  Future<void> Function()? onAddCategory,
}) {
  final options = orderedCategories(
    categories.where((c) => c.isExpense).toList(),
  );
  return AppSheet.show<CategoryPick>(
    context,
    builder: (sheetContext) => CategoryPickerSheet(
      categories: options,
      selectedId: selectedId,
      isIncome: false,
      onAddCategory: () {
        Navigator.of(sheetContext).pop();
        if (onAddCategory != null) unawaited(onAddCategory());
      },
    ),
  );
}

/// A compact category button: the category's avatar and name, or a
/// "Category" prompt when none is chosen.
class CategoryChipButton extends StatelessWidget {
  const CategoryChipButton({
    required this.category,
    required this.onTap,
    this.placeholder = 'Category',
    super.key,
  });

  final Category? category;
  final VoidCallback onTap;
  final String placeholder;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final selected = category;

    return Material(
      color: colors.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(Radii.chip),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 40),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.x1 + 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (selected != null) ...[
                  CategoryAvatar(
                    iconKey: selected.icon,
                    categoryId: selected.id,
                    colorName: selected.color,
                    size: 24,
                  ),
                  const SizedBox(width: 6),
                ] else ...[
                  AppIcon(
                    AppIcons.filter,
                    size: 18,
                    color: colors.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                ],
                Flexible(
                  child: Text(
                    selected?.displayName ?? placeholder,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.metadata(
                      color: selected == null
                          ? colors.onSurfaceVariant
                          : colors.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
