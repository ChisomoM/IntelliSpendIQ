import 'package:flutter/material.dart';
import 'package:intellispendiq/design/design.dart';
import 'package:intellispendiq/domain/models/category.dart';

/// Result of [CategoryPickerSheet]. Distinct from a dismissed sheet so
/// clearing the selection (`categoryId == null`) is intentional.
class CategoryPick {
  const CategoryPick(this.categoryId);
  final String? categoryId;
}

/// Top-level categories first, each followed by its children — the
/// order [CategoryPickerSheet] and any other category list should
/// render in.
List<Category> orderedCategories(List<Category> options) {
  final topLevel = options.where((c) => c.parentId == null).toList();
  final childrenByParent = <String, List<Category>>{};
  for (final category in options.where((c) => c.parentId != null)) {
    childrenByParent
        .putIfAbsent(category.parentId!, () => <Category>[])
        .add(category);
  }

  final ordered = <Category>[];
  for (final parent in topLevel) {
    ordered.add(parent);
    ordered.addAll(childrenByParent.remove(parent.id) ?? const []);
  }
  for (final remaining in childrenByParent.values) {
    ordered.addAll(remaining);
  }
  return ordered;
}

/// Hierarchical category list, shown as a bottom sheet — each row
/// carries the category's own avatar and tint so the list reads as
/// colour, not a wall of identical text. Shared by any field that
/// picks a single category (manual entry, an itemized receipt's
/// per-item category).
class CategoryPickerSheet extends StatelessWidget {
  const CategoryPickerSheet({
    required this.categories,
    required this.selectedId,
    required this.isIncome,
    required this.onAddCategory,
    super.key,
  });

  final List<Category> categories;
  final String? selectedId;
  final bool isIncome;
  final VoidCallback onAddCategory;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final parentsById = {
      for (final category in categories)
        if (category.parentId == null) category.id: category,
    };

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          title: 'Category',
          subtitle: isIncome ? 'Income categories' : 'Spending categories',
          action: 'New',
          onActionTap: onAddCategory,
        ),
        ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.55,
          ),
          child: ListView(
            shrinkWrap: true,
            children: [
              CategoryPickRow(
                label: 'No category',
                subtitle: 'Leave uncategorised',
                selected: selectedId == null,
                onTap: () =>
                    Navigator.of(context).pop(const CategoryPick(null)),
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: AppIcon(
                    AppIcons.close,
                    size: 18,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
              for (final category in categories)
                CategoryPickRow(
                  label: category.displayName,
                  subtitle: category.parentId == null
                      ? null
                      : parentsById[category.parentId!]?.displayName,
                  indent: category.parentId != null,
                  selected: category.id == selectedId,
                  hue: CategoryPalette.forCategory(
                    categoryId: category.id,
                    storedColor: category.color,
                    brightness: Theme.of(context).brightness,
                  ),
                  leading: CategoryAvatar(
                    iconKey: category.icon,
                    categoryId: category.id,
                    colorName: category.color,
                  ),
                  onTap: () =>
                      Navigator.of(context).pop(CategoryPick(category.id)),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class CategoryPickRow extends StatelessWidget {
  const CategoryPickRow({
    required this.label,
    required this.leading,
    required this.selected,
    required this.onTap,
    this.subtitle,
    this.indent = false,
    this.hue,
    super.key,
  });

  final String label;
  final String? subtitle;
  final Widget leading;
  final bool selected;
  final bool indent;
  final CategoryHue? hue;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Every row gets a whisper of its own hue; the selected one gets
    // the full wash so the list never reads as identical grey tiles.
    final wash = hue == null
        ? Colors.transparent
        : selected
        ? hue!.tint.withValues(alpha: isDark ? 0.55 : 0.85)
        : hue!.tint.withValues(alpha: isDark ? 0.18 : 0.35);

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: wash,
        borderRadius: Radii.inputRadius,
        child: InkWell(
          onTap: onTap,
          borderRadius: Radii.inputRadius,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              indent ? Space.x3 : Space.x1,
              Space.x1,
              Space.x1,
              Space.x1,
            ),
            child: Row(
              children: [
                leading,
                const SizedBox(width: Space.x2),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: AppTypography.rowTitle(color: colors.onSurface),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: AppTypography.metadata(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (selected)
                  AppIcon(
                    AppIcons.check,
                    size: 22,
                    color: hue?.ink ?? colors.primary,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
