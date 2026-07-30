import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intellispendiq/budgets/cubit/cubit.dart';
import 'package:intellispendiq/core/money.dart';
import 'package:intellispendiq/domain/models/monthly_income.dart';

/// Every declared income stream for the month, summed against total
/// confirmed spend so far, with each stream editable individually.
class IncomeSummaryCard extends StatelessWidget {
  const IncomeSummaryCard({
    required this.incomeSources,
    required this.totalSpent,
    super.key,
  });

  final List<MonthlyIncome> incomeSources;
  final int totalSpent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (incomeSources.isEmpty) {
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

    final total = incomeSources.fold(
      0,
      (sum, income) => sum + income.amountMinor,
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
                  tooltip: 'Add income stream',
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
              '${Money.format(totalSpent)} spent of ${Money.format(total)}'
              '${over ? ' · over by ${Money.format(totalSpent - total)}' : ' · ${Money.format(total - totalSpent)} left'}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: over ? theme.colorScheme.error : null,
              ),
            ),
            const Divider(height: 24),
            for (final income in incomeSources)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: InkWell(
                  onTap: () =>
                      IncomeEditorSheet.show(context, existing: income),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            income.displayLabel,
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                        Text(
                          Money.format(income.amountMinor),
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

/// Adds a new income stream, or edits/deletes an existing one, for the
/// month the enclosing [BudgetsCubit] is showing.
class IncomeEditorSheet extends StatefulWidget {
  const IncomeEditorSheet({this.existing, super.key});

  final MonthlyIncome? existing;

  static Future<void> show(BuildContext context, {MonthlyIncome? existing}) {
    final cubit = context.read<BudgetsCubit>();
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => BlocProvider.value(
        value: cubit,
        child: IncomeEditorSheet(existing: existing),
      ),
    );
  }

  @override
  State<IncomeEditorSheet> createState() => _IncomeEditorSheetState();
}

class _IncomeEditorSheetState extends State<IncomeEditorSheet> {
  late final TextEditingController _labelController = TextEditingController(
    text: widget.existing?.label ?? '',
  );
  late final TextEditingController _amountController = TextEditingController(
    text: widget.existing == null
        ? ''
        : (widget.existing!.amountMinor / 100).toStringAsFixed(2),
  );
  String? _error;

  @override
  void dispose() {
    _labelController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final navigator = Navigator.of(context);
    final cubit = context.read<BudgetsCubit>();
    final label = _labelController.text.trim().isEmpty
        ? null
        : _labelController.text.trim();
    final existing = widget.existing;
    if (existing == null) {
      await cubit.addIncome(_amountController.text, label: label);
    } else {
      await cubit.updateIncome(
        existing.id,
        _amountController.text,
        label: label,
      );
    }
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
    await context.read<BudgetsCubit>().deleteIncome(widget.existing!.id);
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
            isEditing ? 'Edit income stream' : 'Add income stream',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _labelController,
            decoration: const InputDecoration(
              labelText: 'Source (optional)',
              hintText: 'e.g. Salary, Side hustle',
            ),
            textCapitalization: TextCapitalization.words,
            autofocus: true,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _amountController,
            decoration: InputDecoration(
              labelText: 'Amount',
              prefixText: 'ZMW ',
              errorText: _error,
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp('[0-9.,]')),
            ],
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
