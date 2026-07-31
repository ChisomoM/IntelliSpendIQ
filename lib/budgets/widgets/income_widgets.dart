import 'package:flutter/material.dart';
import 'package:intellispendiq/categories/widgets/widgets.dart';
import 'package:intellispendiq/core/money.dart';
import 'package:intellispendiq/domain/models/category.dart';
import 'package:intellispendiq/domain/models/enums.dart';

/// Every top-level income source for the period — planned amounts listed
/// flat next to total confirmed spend. Users can keep as many income
/// sources as they need (salary, side hustle, etc.).
class IncomeSummaryCard extends StatelessWidget {
  const IncomeSummaryCard({
    required this.incomeCategories,
    required this.totalSpent,
    this.periodId,
    super.key,
  });

  /// Top-level income categories, including those without a plan yet.
  final List<Category> incomeCategories;
  final int totalSpent;

  /// Budget period to write planned amounts into when editing.
  final String? periodId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final planned = incomeCategories.where((c) => c.hasBudget).toList();
    final total = planned.fold(
      0,
      (sum, category) => sum + category.budgetedAmountMinor!,
    );

    if (incomeCategories.isEmpty) {
      return Card(
        child: ListTile(
          leading: const Icon(Icons.payments_outlined),
          title: const Text('Add an income source'),
          subtitle: const Text(
            'Salary, side hustle, or anything else you earn — '
            'you can add as many as you need.',
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _openEditor(context),
        ),
      );
    }

    if (planned.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Income sources',
                      style: theme.textTheme.titleSmall,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add, size: 20),
                    tooltip: 'Add income source',
                    onPressed: () => _openEditor(context),
                  ),
                ],
              ),
              Text(
                'Set a planned amount on each source you earn from.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              for (final category in incomeCategories)
                _IncomeSourceRow(
                  category: category,
                  periodId: periodId,
                ),
            ],
          ),
        ),
      );
    }

    final ratio = total == 0 ? 0.0 : totalSpent / total;
    final over = totalSpent > total;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Income sources',
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add, size: 20),
                  tooltip: 'Add income source',
                  onPressed: () => _openEditor(context),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: LinearProgressIndicator(
                value: ratio.clamp(0.0, 1.0),
                color: over ? theme.colorScheme.error : null,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(
                '${Money.format(totalSpent)} spent of ${Money.format(total)}'
                '${over ? ' · over by ${Money.format(totalSpent - total)}' : ' · ${Money.format(total - totalSpent)} left'}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: over ? theme.colorScheme.error : null,
                ),
              ),
            ),
            const Divider(height: 24),
            for (final category in incomeCategories)
              _IncomeSourceRow(
                category: category,
                periodId: periodId,
              ),
          ],
        ),
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
  const _IncomeSourceRow({
    required this.category,
    this.periodId,
  });

  final Category category;
  final String? periodId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () => Navigator.of(context).push<String?>(
        CategoryEditorPage.route(
          existing: category,
          periodId: periodId,
        ),
      ),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Expanded(
              child: Text(
                category.displayName,
                style: theme.textTheme.bodyMedium,
              ),
            ),
            Text(
              category.hasBudget
                  ? Money.format(category.budgetedAmountMinor!)
                  : 'Set amount',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: category.hasBudget
                    ? null
                    : theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.chevron_right,
              size: 18,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}
