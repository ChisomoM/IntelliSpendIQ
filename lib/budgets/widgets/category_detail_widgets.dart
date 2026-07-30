import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intellispendiq/budgets/cubit/cubit.dart';
import 'package:intellispendiq/core/money.dart';
import 'package:intellispendiq/domain/models/category.dart';

/// Budgeted / spent / remaining, side by side.
class CategoryStatTiles extends StatelessWidget {
  const CategoryStatTiles({
    required this.budgetedMinor,
    required this.spentMinor,
    required this.remainingMinor,
    super.key,
  });

  final int budgetedMinor;
  final int spentMinor;
  final int remainingMinor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatTile(label: 'Budgeted', amountMinor: budgetedMinor),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatTile(label: 'Spent', amountMinor: spentMinor),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatTile(label: 'Remaining', amountMinor: remainingMinor),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.amountMinor});

  final String label;
  final int amountMinor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: theme.textTheme.bodySmall),
            const SizedBox(height: 4),
            Text(
              Money.format(amountMinor),
              style: theme.textTheme.titleMedium,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

/// A circular percent-spent gauge.
class BudgetGauge extends StatelessWidget {
  const BudgetGauge({
    required this.spentMinor,
    required this.budgetedMinor,
    super.key,
  });

  final int spentMinor;
  final int budgetedMinor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ratio = budgetedMinor == 0 ? 0.0 : spentMinor / budgetedMinor;
    final over = spentMinor > budgetedMinor && budgetedMinor > 0;

    return SizedBox(
      width: 140,
      height: 140,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 140,
            height: 140,
            child: CircularProgressIndicator(
              value: ratio.clamp(0.0, 1.0),
              strokeWidth: 10,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              color: over ? theme.colorScheme.error : theme.colorScheme.primary,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${(ratio * 100).clamp(0, 999).toStringAsFixed(0)}%',
                style: theme.textTheme.headlineSmall,
              ),
              Text('Budget spent', style: theme.textTheme.bodySmall),
            ],
          ),
        ],
      ),
    );
  }
}

/// One subcategory row: spent vs planned (or just spent, if it has no
/// budget of its own).
class SubcategoryRow extends StatelessWidget {
  const SubcategoryRow({
    required this.category,
    required this.spentMinor,
    super.key,
  });

  final Category category;
  final int spentMinor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final budgeted = category.budgetedAmountMinor;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(category.displayName, style: theme.textTheme.titleSmall),
            const SizedBox(height: 6),
            if (budgeted == null)
              Text(
                '${Money.format(spentMinor)} spent',
                style: theme.textTheme.bodySmall,
              )
            else ...[
              LinearProgressIndicator(
                value: budgeted == 0
                    ? 0
                    : (spentMinor / budgeted).clamp(0.0, 1.0),
                color: spentMinor > budgeted ? theme.colorScheme.error : null,
              ),
              const SizedBox(height: 6),
              Text(
                '${Money.format(spentMinor)} of ${Money.format(budgeted)} spent'
                '${spentMinor > budgeted ? '' : ' · ${Money.format(budgeted - spentMinor)} remain'}',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Moves budget from the category the enclosing [CategoryDetailCubit]
/// is showing to another top-level category of the same type.
class BudgetTransferSheet extends StatefulWidget {
  const BudgetTransferSheet({super.key});

  static Future<void> show(BuildContext context) {
    final cubit = context.read<CategoryDetailCubit>();
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => BlocProvider.value(
        value: cubit,
        child: const BudgetTransferSheet(),
      ),
    );
  }

  @override
  State<BudgetTransferSheet> createState() => _BudgetTransferSheetState();
}

class _BudgetTransferSheetState extends State<BudgetTransferSheet> {
  final _amountController = TextEditingController();
  String? _targetId;
  String? _error;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _transfer() async {
    if (_targetId == null) {
      setState(() => _error = 'Pick a category to move it to');
      return;
    }
    final navigator = Navigator.of(context);
    final cubit = context.read<CategoryDetailCubit>();
    await cubit.transferTo(_targetId!, _amountController.text);
    if (!mounted) return;
    if (cubit.state.status == CategoryDetailStatus.invalid) {
      setState(() => _error = cubit.state.errorMessage);
      return;
    }
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final targets = context.read<CategoryDetailCubit>().state.transferTargets;

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
            'Transfer budget',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          if (targets.isEmpty)
            const Text('No other category of the same type to move it to.')
          else ...[
            DropdownButtonFormField<String>(
              initialValue: _targetId,
              decoration: const InputDecoration(labelText: 'Move to'),
              items: [
                for (final target in targets)
                  DropdownMenuItem(
                    value: target.id,
                    child: Text(target.displayName),
                  ),
              ],
              onChanged: (value) => setState(() => _targetId = value),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _amountController,
              decoration: InputDecoration(
                labelText: 'Amount',
                prefixText: 'ZMW ',
                errorText: _error,
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp('[0-9.,]')),
              ],
              autofocus: true,
            ),
            const SizedBox(height: 24),
            FilledButton(onPressed: _transfer, child: const Text('Transfer')),
          ],
        ],
      ),
    );
  }
}
