import 'package:flutter/material.dart';
import 'package:intellispendiq/categories/widgets/widgets.dart';
import 'package:intellispendiq/design/design.dart';
import 'package:intellispendiq/domain/models/category.dart';
import 'package:intellispendiq/domain/models/enums.dart';

/// Every top-level income source for the period, with its planned
/// amount and a total underneath.
///
/// Spend is not tracked against income here: the hero above already
/// tracks it against the budget, and showing the same spend against a
/// second, different denominator on one screen invited the reading that
/// they were two separate problems.
class IncomeSummaryCard extends StatelessWidget {
  const IncomeSummaryCard({
    required this.incomeCategories,
    this.periodId,
    super.key,
  });

  /// Top-level income categories, including those without a plan yet.
  final List<Category> incomeCategories;

  /// Budget period to write planned amounts into when editing.
  final String? periodId;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final money = Theme.of(context).extension<MoneyColors>()!;
    final planned = incomeCategories.where((c) => c.hasBudget).toList();
    final total = planned.fold(
      0,
      (sum, category) => sum + category.budgetedAmountMinor!,
    );

    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Space.x2,
              Space.x2,
              Space.x2,
              Space.x1,
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: money.inflow.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(Radii.card),
                  ),
                  alignment: Alignment.center,
                  child: AppIcon(
                    AppIcons.moneyIn,
                    size: 20,
                    color: money.inflow,
                  ),
                ),
                const SizedBox(width: Space.x2),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Income', style: AppTypography.rowTitle()),
                      const SizedBox(height: 2),
                      Text(
                        'Money coming in this period',
                        style: AppTypography.metadata(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _openEditor(context),
                  icon: AppIcon(AppIcons.add, size: 16, color: colors.primary),
                  label: const Text('Add'),
                ),
              ],
            ),
          ),
          if (incomeCategories.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Space.x2,
                0,
                Space.x2,
                Space.x2,
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Salary, side hustle, or anything else you earn.',
                  style: AppTypography.metadata(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
            )
          else ...[
            for (final category in incomeCategories)
              _IncomeSourceRow(category: category, periodId: periodId),
            if (planned.isNotEmpty) ...[
              Divider(height: 1, color: colors.outlineVariant),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Space.x2,
                  Space.x2,
                  Space.x2,
                  Space.x2,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Total income',
                        style: AppTypography.rowTitle(color: colors.onSurface),
                      ),
                    ),
                    MoneyText.signed(total, isInflow: true),
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  void _openEditor(BuildContext context) {
    Navigator.of(context).push<String?>(
      CategoryEditorPage.route(
        initialType: CategoryType.income,
        periodId: periodId,
      ),
    );
  }
}

class _IncomeSourceRow extends StatelessWidget {
  const _IncomeSourceRow({required this.category, this.periodId});

  final Category category;
  final String? periodId;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return AppListRow(
      leading: CategoryAvatar(
        iconKey: category.icon,
        categoryId: category.id,
        colorName: category.color,
        size: 36,
      ),
      title: Text(category.name),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (category.hasBudget)
            MoneyText(category.budgetedAmountMinor!, size: MoneySize.meta)
          else
            Text(
              'Set amount',
              style: AppTypography.metadata(color: colors.primary),
            ),
          const SizedBox(width: 4),
          AppIcon(
            AppIcons.chevronRight,
            size: 18,
            color: colors.onSurfaceVariant,
          ),
        ],
      ),
      onTap: () => Navigator.of(context).push<String?>(
        CategoryEditorPage.route(existing: category, periodId: periodId),
      ),
    );
  }
}
