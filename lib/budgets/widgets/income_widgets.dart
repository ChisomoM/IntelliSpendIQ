import 'package:flutter/material.dart';
import 'package:intellispendiq/categories/widgets/widgets.dart';
import 'package:intellispendiq/core/money.dart';
import 'package:intellispendiq/domain/models/category.dart';
import 'package:intellispendiq/domain/models/enums.dart';

/// Every income category with a planned amount, listed flat next to
/// total confirmed spend so far — income categories don't track
/// spent-vs-planned the way expense envelopes do, they're just a
/// named figure, same as the reference this was modeled on.
class IncomeSummaryCard extends StatelessWidget {
  const IncomeSummaryCard({
    required this.incomeCategories,
    required this.totalSpent,
    super.key,
  });

  final List<Category> incomeCategories;
  final int totalSpent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (incomeCategories.isEmpty) {
      return Card(
        child: ListTile(
          leading: const Icon(Icons.payments_outlined),
          title: const Text('Set your income for this month'),
          subtitle: const Text(
            'Track total spend against what you actually earn.',
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).push<String?>(
            CategoryEditorPage.route(initialType: CategoryType.income),
          ),
        ),
      );
    }

    final total = incomeCategories.fold(
      0,
      (sum, category) => sum + category.budgetedAmountMinor!,
    );
    final ratio = total == 0 ? 0.0 : totalSpent / total;
    final over = totalSpent > total;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Income', style: theme.textTheme.titleSmall),
                ),
                IconButton(
                  icon: const Icon(Icons.add, size: 20),
                  tooltip: 'Add income category',
                  onPressed: () => Navigator.of(context).push<String?>(
                    CategoryEditorPage.route(initialType: CategoryType.income),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: ratio.clamp(0.0, 1.0),
              color: over ? theme.colorScheme.error : null,
            ),
            const SizedBox(height: 8),
            Text(
              '${Money.format(totalSpent)} spent of ${Money.format(total)}'
              '${over ? ' · over by ${Money.format(totalSpent - total)}' : ' · ${Money.format(total - totalSpent)} left'}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: over ? theme.colorScheme.error : null,
              ),
            ),
            const Divider(height: 24),
            for (final category in incomeCategories)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: InkWell(
                  onTap: () => Navigator.of(context).push<String?>(
                    CategoryEditorPage.route(existing: category),
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
                          Money.format(category.budgetedAmountMinor!),
                          style: theme.textTheme.bodyMedium,
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
                ),
              ),
          ],
        ),
      ),
    );
  }
}
