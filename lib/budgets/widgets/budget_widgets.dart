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

/// Overall monthly budget next to total confirmed spend. Category
/// limits are separate allocations and do not define this figure.
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

    if (plannedMinor == 0) {
      return Card(
        child: ListTile(
          leading: const Icon(Icons.account_balance_wallet_outlined),
          title: const Text('Set your total budget'),
          subtitle: const Text(
            'Track overall spend against your monthly plan. '
            'Category limits are optional allocations under this.',
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => OverallBudgetEditorSheet.show(context),
        ),
      );
    }

    final ratio = totalSpent / plannedMinor;
    final over = totalSpent > plannedMinor;

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
                    'Total budget',
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  tooltip: 'Edit total budget',
                  onPressed: () => OverallBudgetEditorSheet.show(
                    context,
                    existing: overallBudget,
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
              '${Money.format(totalSpent)} spent of ${Money.format(plannedMinor)}'
              '${over ? ' · over by ${Money.format(totalSpent - plannedMinor)}' : ' · ${Money.format(plannedMinor - totalSpent)} left'}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: over ? theme.colorScheme.error : null,
              ),
            ),
            if (allocatedMinor > 0) ...[
              const SizedBox(height: 4),
              Text(
                '${Money.format(allocatedMinor)} allocated across categories',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
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
            isEditing ? 'Edit total budget' : 'Set total budget',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Your overall monthly spending plan. Category limits '
            'are optional and sit under this total.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _amountController,
            decoration: InputDecoration(
              labelText: 'Monthly budget',
              prefixText: 'ZMW ',
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
    super.key,
  });

  final Category category;
  final int spentMinor;

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
          CategoryDetailPage.route(categoryId: category.id),
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
              'Optionally set a monthly limit per category under your '
              'total budget.',
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
