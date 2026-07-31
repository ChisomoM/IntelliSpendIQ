import 'package:flutter/material.dart';
import 'package:intellispendiq/core/money.dart';
import 'package:intellispendiq/data/repositories/transaction_repository.dart';
import 'package:intellispendiq/domain/models/transaction.dart';
import 'package:intellispendiq/transactions/widgets/widgets.dart';

class GreetingHeader extends StatelessWidget {
  const GreetingHeader({required this.period, super.key});

  final String period;

  String get _greeting => switch (DateTime.now().hour) {
    < 12 => 'Good morning',
    < 17 => 'Good afternoon',
    _ => 'Good evening',
  };

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(_greeting, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 2),
        Text(
          'Here is how $period is looking',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// Read-only spend-vs-income summary. Tapping opens Budgets, which
/// owns the actual income figure and its editor.
class IncomeOverviewCard extends StatelessWidget {
  const IncomeOverviewCard({
    required this.hasIncome,
    required this.incomeMinor,
    required this.totalSpent,
    required this.onTap,
    super.key,
  });

  final bool hasIncome;
  final int incomeMinor;
  final int totalSpent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (!hasIncome) {
      return Card(
        child: ListTile(
          leading: const Icon(Icons.payments_outlined),
          title: const Text('Set your income for this month'),
          subtitle: const Text('Track spend against what you earn.'),
          trailing: const Icon(Icons.chevron_right),
          onTap: onTap,
        ),
      );
    }

    final ratio = incomeMinor == 0 ? 0.0 : totalSpent / incomeMinor;
    final over = totalSpent > incomeMinor;

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'This month',
                      style: theme.textTheme.titleSmall,
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    color: theme.colorScheme.onSurfaceVariant,
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
                '${Money.format(totalSpent)} spent of ${Money.format(incomeMinor)}'
                '${over ? ' · over by ${Money.format(totalSpent - incomeMinor)}' : ' · ${Money.format(incomeMinor - totalSpent)} left'}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: over ? theme.colorScheme.error : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TopCategoriesCard extends StatelessWidget {
  const TopCategoriesCard({
    required this.categories,
    required this.onSeeAll,
    super.key,
  });

  final List<CategorySpend> categories;
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final largest = categories.first.spentMinor;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Top categories',
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                TextButton(onPressed: onSeeAll, child: const Text('See all')),
              ],
            ),
            for (final category in categories) ...[
              const SizedBox(height: 8),
              Text(category.categoryName, style: theme.textTheme.bodyMedium),
              const SizedBox(height: 4),
              LinearProgressIndicator(
                value: largest == 0 ? 0 : category.spentMinor / largest,
              ),
              const SizedBox(height: 2),
              Text(
                Money.format(category.spentMinor),
                style: theme.textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class RecentActivityCard extends StatelessWidget {
  const RecentActivityCard({
    required this.transactions,
    required this.onSeeAll,
    super.key,
  });

  final List<Transaction> transactions;
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) {
    if (transactions.isEmpty) return const SizedBox.shrink();

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 8, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Recent activity',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                TextButton(
                  onPressed: onSeeAll,
                  child: const Text('See all'),
                ),
              ],
            ),
          ),
          for (final transaction in transactions)
            TransactionTile(transaction: transaction),
        ],
      ),
    );
  }
}

/// Prompts a trip to the Review Inbox when something is waiting.
/// Absent entirely once the inbox is empty — there is nothing to nag
/// the user about.
class ReviewBanner extends StatelessWidget {
  const ReviewBanner({required this.count, required this.onTap, super.key});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (count == 0) return const SizedBox.shrink();
    final theme = Theme.of(context);

    return Card(
      color: theme.colorScheme.tertiaryContainer,
      child: ListTile(
        leading: Icon(
          Icons.inbox_outlined,
          color: theme.colorScheme.onTertiaryContainer,
        ),
        title: Text(
          count == 1 ? '1 item needs a look' : '$count items need a look',
          style: TextStyle(color: theme.colorScheme.onTertiaryContainer),
        ),
        subtitle: Text(
          'Duplicates, low-confidence entries, and unparsed messages',
          style: TextStyle(color: theme.colorScheme.onTertiaryContainer),
        ),
        trailing: Icon(
          Icons.chevron_right,
          color: theme.colorScheme.onTertiaryContainer,
        ),
        onTap: onTap,
      ),
    );
  }
}

/// Speaking an entry, as an explicit button.
///
/// The capture FAB records voice on a long press, but a gesture is a
/// shortcut for people who already know it — never the only way in. This
/// is the discoverable route, and it is why the long press is allowed to
/// stay hidden.
class VoiceCaptureButton extends StatelessWidget {
  const VoiceCaptureButton({required this.onPressed, super.key});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.mic_none, size: 20),
        label: const Text('Say what you spent'),
      ),
    );
  }
}
