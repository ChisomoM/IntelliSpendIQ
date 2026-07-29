import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intellispendiq/budgets/cubit/cubit.dart';
import 'package:intellispendiq/core/money.dart';
import 'package:intellispendiq/domain/models/monthly_income.dart';

/// Declared income for the month next to total confirmed spend so far,
/// tracked independently of the per-category budget cards below it.
class IncomeSummaryCard extends StatelessWidget {
  const IncomeSummaryCard({
    required this.income,
    required this.totalSpent,
    super.key,
  });

  final MonthlyIncome? income;
  final int totalSpent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (income == null) {
      return Card(
        child: ListTile(
          leading: const Icon(Icons.payments_outlined),
          title: const Text('Set your income for this month'),
          subtitle: const Text(
            'Track total spend against what you actually earn.',
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => IncomeEditorSheet.show(context),
        ),
      );
    }

    final limit = income!.amountMinor;
    final ratio = limit == 0 ? 0.0 : totalSpent / limit;
    final over = totalSpent > limit;

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
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  onPressed: () => IncomeEditorSheet.show(context),
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
              '${Money.format(totalSpent)} spent of ${Money.format(limit)}'
              '${over ? ' · over by ${Money.format(totalSpent - limit)}' : ' · ${Money.format(limit - totalSpent)} left'}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: over ? theme.colorScheme.error : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Sets or updates the declared income for the month the enclosing
/// [BudgetsCubit] is showing.
class IncomeEditorSheet extends StatefulWidget {
  const IncomeEditorSheet({super.key});

  static Future<void> show(BuildContext context) {
    final cubit = context.read<BudgetsCubit>();
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => BlocProvider.value(
        value: cubit,
        child: const IncomeEditorSheet(),
      ),
    );
  }

  @override
  State<IncomeEditorSheet> createState() => _IncomeEditorSheetState();
}

class _IncomeEditorSheetState extends State<IncomeEditorSheet> {
  late final TextEditingController _amountController = TextEditingController(
    text: context.read<BudgetsCubit>().state.income == null
        ? ''
        : (context.read<BudgetsCubit>().state.income!.amountMinor / 100)
              .toStringAsFixed(2),
  );
  String? _error;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final navigator = Navigator.of(context);
    await context.read<BudgetsCubit>().setIncome(_amountController.text);
    if (!mounted) return;
    final state = context.read<BudgetsCubit>().state;
    if (state.status == BudgetsStatus.invalid) {
      setState(() => _error = state.errorMessage);
      return;
    }
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
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
            'Income for the month',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _amountController,
            decoration: InputDecoration(
              labelText: 'Income',
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
          FilledButton(onPressed: _save, child: const Text('Save')),
        ],
      ),
    );
  }
}
