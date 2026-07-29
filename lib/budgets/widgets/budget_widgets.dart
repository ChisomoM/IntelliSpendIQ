import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intellispendiq/budgets/cubit/cubit.dart';
import 'package:intellispendiq/core/money.dart';
import 'package:intellispendiq/domain/models/budget.dart';

class BudgetCard extends StatelessWidget {
  const BudgetCard({
    required this.budget,
    required this.categoryName,
    required this.spentMinor,
    super.key,
  });

  final Budget budget;
  final String categoryName;
  final int spentMinor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final limit = budget.amountMinor;
    final ratio = limit == 0 ? 0.0 : spentMinor / limit;
    final over = spentMinor > limit;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(categoryName, style: theme.textTheme.titleSmall),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  onPressed: () =>
                      BudgetEditorSheet.show(context, existing: budget),
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
              '${Money.format(spentMinor)} of ${Money.format(limit)}'
              '${over ? ' · over by ${Money.format(spentMinor - limit)}' : ' · ${Money.format(limit - spentMinor)} left'}',
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

/// Create or edit a monthly limit. Hosted by the page's [BudgetsCubit]
/// so the list updates as soon as the write lands.
class BudgetEditorSheet extends StatefulWidget {
  const BudgetEditorSheet({this.existing, super.key});

  final Budget? existing;

  static Future<void> show(BuildContext context, {Budget? existing}) {
    final cubit = context.read<BudgetsCubit>();
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => BlocProvider.value(
        value: cubit,
        child: BudgetEditorSheet(existing: existing),
      ),
    );
  }

  @override
  State<BudgetEditorSheet> createState() => _BudgetEditorSheetState();
}

class _BudgetEditorSheetState extends State<BudgetEditorSheet> {
  late final TextEditingController _amountController = TextEditingController(
    text: widget.existing == null
        ? ''
        : (widget.existing!.amountMinor / 100).toStringAsFixed(2),
  );
  late String? _categoryId = widget.existing?.categoryId;
  String? _error;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_categoryId == null) {
      setState(() => _error = 'Pick a category');
      return;
    }
    final navigator = Navigator.of(context);
    await context.read<BudgetsCubit>().upsert(
      categoryId: _categoryId!,
      amount: _amountController.text,
    );
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
    final cubit = context.read<BudgetsCubit>();
    final categories = cubit.state.categories;

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
            widget.existing == null ? 'Set a budget' : 'Edit budget',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: categories.any((c) => c.id == _categoryId)
                ? _categoryId
                : null,
            decoration: const InputDecoration(labelText: 'Category'),
            items: [
              for (final category in categories)
                DropdownMenuItem(
                  value: category.id,
                  child: Text(category.displayName),
                ),
            ],
            onChanged: widget.existing != null
                ? null
                : (value) => setState(() => _categoryId = value),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _amountController,
            decoration: InputDecoration(
              labelText: 'Monthly limit',
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
              if (widget.existing != null)
                TextButton(
                  onPressed: () async {
                    final navigator = Navigator.of(context);
                    await cubit.delete(widget.existing!.id);
                    navigator.pop();
                  },
                  child: const Text('Delete'),
                ),
              const Spacer(),
              FilledButton(onPressed: _save, child: const Text('Save')),
            ],
          ),
        ],
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
              'No budgets yet',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Set a monthly limit per category to track over- and '
              'under-spending. Limits carry into the next month as '
              'editable defaults.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => BudgetEditorSheet.show(context),
              child: const Text('Set a budget'),
            ),
          ],
        ),
      ),
    );
  }
}
