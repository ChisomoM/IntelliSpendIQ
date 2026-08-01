import 'package:flutter/material.dart';
import 'package:intellispendiq/categories/widgets/widgets.dart';
import 'package:intellispendiq/design/design.dart';
import 'package:intellispendiq/domain/models/category.dart';
import 'package:intellispendiq/domain/models/enums.dart';

/// Every top-level income source for the period, with its planned
/// amount. Users can keep as many as they need — salary, side hustle,
/// and so on.
///
/// Spend is no longer tracked against income here: the hero card above
/// already tracks it against the budget, and showing the same spend
/// against a second, different denominator on one screen invited the
/// reading that they were two separate problems.
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
    final planned = incomeCategories.where((c) => c.hasBudget).toList();
    final total = planned.fold(
      0,
      (sum, category) => sum + category.budgetedAmountMinor!,
    );

    if (incomeCategories.isEmpty) {
      return AppCard(
        onTap: () => _openEditor(context),
        child: Row(
          children: [
            AppIcon(AppIcons.moneyIn, color: colors.secondary),
            const SizedBox(width: Space.x2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Add an income source', style: AppTypography.rowTitle()),
                  const SizedBox(height: 2),
                  Text(
                    'Salary, side hustle, or anything else you earn.',
                    style: AppTypography.metadata(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            AppIcon(AppIcons.chevronRight, size: 20),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Income',
          action: 'Add',
          onActionTap: () => _openEditor(context),
        ),
        AppCard(
          padding: const EdgeInsets.symmetric(vertical: Space.x1),
          child: Column(
            children: [
              for (final category in incomeCategories)
                _IncomeSourceRow(category: category, periodId: periodId),
              if (planned.isNotEmpty) ...[
                const Divider(height: Space.x2),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Space.gutter,
                    vertical: 4,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Total expected',
                          style: AppTypography.rowTitle(
                            color: colors.onSurface,
                          ),
                        ),
                      ),
                      MoneyText.signed(total, isInflow: true),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
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
      leading: CategoryAvatar(iconKey: category.icon, size: 32),
      title: Text(category.name),
      trailing: category.hasBudget
          ? MoneyText(category.budgetedAmountMinor!, size: MoneySize.meta)
          : Text(
              'Set amount',
              style: AppTypography.metadata(color: colors.secondary),
            ),
      onTap: () => Navigator.of(context).push<String?>(
        CategoryEditorPage.route(existing: category, periodId: periodId),
      ),
    );
  }
}
