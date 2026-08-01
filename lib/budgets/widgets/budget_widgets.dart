import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intellispendiq/budgets/cubit/cubit.dart';
import 'package:intellispendiq/budgets/view/category_detail_page.dart';
import 'package:intellispendiq/categories/widgets/widgets.dart';
import 'package:intellispendiq/core/money.dart';
import 'package:intellispendiq/domain/models/category.dart';
import 'package:intellispendiq/domain/models/enums.dart';
import 'package:intellispendiq/domain/models/overall_budget.dart';

/// Planned (overall period target) and Allocated (sum of category
/// envelopes) as peer figures, with confirmed spend tracked against
/// Planned.
class PlannedVsActualCard extends StatelessWidget {
  const PlannedVsActualCard({
    required this.plannedMinor,
    required this.totalSpent,
    this.allocatedMinor = 0,
    this.overallBudget,
    super.key,
  });

  final int plannedMinor;
  final int totalSpent;
  final int allocatedMinor;
  final OverallBudget? overallBudget;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasPlanned = plannedMinor > 0;

    if (!hasPlanned && allocatedMinor == 0) {
      return Card(
        child: ListTile(
          leading: const Icon(Icons.account_balance_wallet_outlined),
          title: const Text('Set your planned budget'),
          subtitle: const Text(
            'How much you want to budget this period. '
            'Allocated is the total of your category budgets.',
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => OverallBudgetEditorSheet.show(context),
        ),
      );
    }

    final overSpend = hasPlanned && totalSpent > plannedMinor;
    final allocationDelta = allocatedMinor - plannedMinor;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Budgets',
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  tooltip: hasPlanned
                      ? 'Edit planned budget'
                      : 'Set planned budget',
                  onPressed: () => OverallBudgetEditorSheet.show(
                    context,
                    existing: overallBudget,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _BudgetFigure(
                    label: 'Planned',
                    amountMinor: hasPlanned ? plannedMinor : null,
                    emptyLabel: 'Not set',
                    caption: 'How much you want to budget',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _BudgetFigure(
                    label: 'Allocated',
                    amountMinor: allocatedMinor > 0 ? allocatedMinor : null,
                    emptyLabel: 'None yet',
                    caption: 'Total of budgeted categories',
                  ),
                ),
              ],
            ),
            if (hasPlanned) ...[
              const SizedBox(height: 16),
              LinearProgressIndicator(
                value: (totalSpent / plannedMinor).clamp(0.0, 1.0),
                color: overSpend ? theme.colorScheme.error : null,
              ),
              const SizedBox(height: 8),
              Text(
                '${Money.format(totalSpent)} spent of '
                '${Money.format(plannedMinor)}'
                '${overSpend ? ' · over by ${Money.format(totalSpent - plannedMinor)}' : ' · ${Money.format(plannedMinor - totalSpent)} left'}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: overSpend ? theme.colorScheme.error : null,
                ),
              ),
            ],
            if (hasPlanned && allocatedMinor > 0) ...[
              const SizedBox(height: 4),
              Text(
                allocationDelta == 0
                    ? 'Fully allocated'
                    : allocationDelta < 0
                        ? '${Money.format(-allocationDelta)} left to allocate'
                        : 'Over-allocated by ${Money.format(allocationDelta)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: allocationDelta > 0
                      ? theme.colorScheme.error
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BudgetFigure extends StatelessWidget {
  const _BudgetFigure({
    required this.label,
    required this.amountMinor,
    required this.emptyLabel,
    required this.caption,
  });

  final String label;
  final int? amountMinor;
  final String emptyLabel;
  final String caption;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(color: muted),
        ),
        const SizedBox(height: 4),
        Text(
          amountMinor == null ? emptyLabel : Money.format(amountMinor!),
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: amountMinor == null ? muted : null,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          caption,
          style: theme.textTheme.bodySmall?.copyWith(color: muted),
        ),
      ],
    );
  }
}

/// Create or edit the month's overall budget, independent of category
/// limits. Hosted by the page's [BudgetsCubit].
class OverallBudgetEditorSheet extends StatefulWidget {
  const OverallBudgetEditorSheet({this.existing, super.key});

  final OverallBudget? existing;

  static Future<void> show(
    BuildContext context, {
    OverallBudget? existing,
  }) {
    final cubit = context.read<BudgetsCubit>();
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => BlocProvider.value(
        value: cubit,
        child: OverallBudgetEditorSheet(existing: existing),
      ),
    );
  }

  @override
  State<OverallBudgetEditorSheet> createState() =>
      _OverallBudgetEditorSheetState();
}

class _OverallBudgetEditorSheetState extends State<OverallBudgetEditorSheet> {
  late final TextEditingController _amountController = TextEditingController(
    text: widget.existing == null
        ? ''
        : (widget.existing!.amountMinor / 100).toStringAsFixed(2),
  );
  String? _error;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final navigator = Navigator.of(context);
    await context.read<BudgetsCubit>().setOverallBudget(
      _amountController.text,
    );
    if (!mounted) return;
    final state = context.read<BudgetsCubit>().state;
    if (state.status == BudgetsStatus.invalid) {
      setState(() => _error = state.errorMessage);
      return;
    }
    navigator.pop();
  }

  Future<void> _delete() async {
    final navigator = Navigator.of(context);
    await context.read<BudgetsCubit>().deleteOverallBudget();
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existing != null;

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            isEditing ? 'Edit planned budget' : 'Set planned budget',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'How much you want to budget this period. '
            'Allocated is the total of your category budgets.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _amountController,
            decoration: InputDecoration(
              labelText: 'Planned budget',
              prefixText: 'K',
              errorText: _error,
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp('[0-9.,]')),
            ],
            autofocus: true,
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              if (isEditing)
                TextButton(onPressed: _delete, child: const Text('Delete')),
              const Spacer(),
              FilledButton(onPressed: _save, child: const Text('Save')),
            ],
          ),
        ],
      ),
    );
  }
}

/// A top-level expense category with a budget set. Tapping opens its
/// detail page — subcategories, transfer, the full spent-vs-planned
/// breakdown — editing here is just the quick summary.
class ExpenseCategoryEnvelopeCard extends StatelessWidget {
  const ExpenseCategoryEnvelopeCard({
    required this.category,
    required this.spentMinor,
    this.periodId,
    this.periodStartAt,
    this.periodEndAt,
    super.key,
  });

  final Category category;
  final int spentMinor;

  /// Active budget period — forwarded into category detail.
  final String? periodId;
  final String? periodStartAt;
  final String? periodEndAt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final limit = category.budgetedAmountMinor!;
    final ratio = limit == 0 ? 0.0 : spentMinor / limit;
    final over = spentMinor > limit;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => Navigator.of(context).push<void>(
          CategoryDetailPage.route(
            categoryId: category.id,
            periodId: periodId,
            periodStartAt: periodStartAt,
            periodEndAt: periodEndAt,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      category.displayName,
                      style: theme.textTheme.titleSmall,
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: ratio.clamp(0.0, 1.0),
                color: over ? theme.colorScheme.error : null,
              ),
              const SizedBox(height: 8),
              Text(
                '${Money.format(spentMinor)} of ${Money.format(limit)}'
                '${over ? ' · over by ${Money.format(spentMinor - limit)}' : ' · ${Money.format(limit - spentMinor)} left'}',
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

class NoBudgetsYet extends StatelessWidget {
  const NoBudgetsYet({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.savings_outlined, size: 48),
            const SizedBox(height: 16),
            const Text(
              'No category budgets yet',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Add category budgets to build your Allocated total '
              'under the Planned budget.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => Navigator.of(context).push<String?>(
                CategoryEditorPage.route(initialType: CategoryType.expense),
              ),
              child: const Text('Add category budget'),
            ),
          ],
        ),
      ),
    );
  }
}
