import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intellispendiq/app/app.dart';
import 'package:intellispendiq/core/money.dart';
import 'package:intellispendiq/core/time.dart';
import 'package:intellispendiq/data/db/app_database.dart';

/// Budget CRUD with live over/under against confirmed spend (plan §11).
/// All math is local SQL — no LLM anywhere near the numbers.
class BudgetsPage extends StatefulWidget {
  const BudgetsPage({super.key});

  @override
  State<BudgetsPage> createState() => _BudgetsPageState();
}

class _BudgetsPageState extends State<BudgetsPage> {
  late final String _period = Iso.monthKey(DateTime.now());
  bool _carryOverChecked = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_carryOverChecked) return;
    _carryOverChecked = true;
    // New month: bring last month's budgets forward as editable
    // defaults, without touching anything already set for this month.
    unawaited(AppScope.of(context).budgets.carryOverInto(_period));
  }

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Budgets'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Set a budget',
            onPressed: () => _showEditor(context),
          ),
        ],
      ),
      body: StreamBuilder<List<BudgetRow>>(
        stream: services.budgets.watchForPeriod(_period),
        builder: (context, budgetSnapshot) {
          final budgets = budgetSnapshot.data ?? const <BudgetRow>[];
          if (budgets.isEmpty) {
            return _EmptyBudgets(onAdd: () => _showEditor(context));
          }
          return StreamBuilder<List<CategoryRow>>(
            stream: services.categories.watchAll(),
            builder: (context, categorySnapshot) {
              final categories = categorySnapshot.data ?? const <CategoryRow>[];
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    'Month of $_period',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  for (final budget in budgets)
                    _BudgetCard(
                      budget: budget,
                      categoryName: categories
                          .where((c) => c.id == budget.categoryId)
                          .map((c) => '${c.icon ?? ''} ${c.name}')
                          .firstOrNull,
                      period: _period,
                      onEdit: () => _showEditor(context, existing: budget),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _showEditor(BuildContext context, {BudgetRow? existing}) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _BudgetEditorSheet(period: _period, existing: existing),
    );
  }
}

class _BudgetCard extends StatelessWidget {
  const _BudgetCard({
    required this.budget,
    required this.categoryName,
    required this.period,
    required this.onEdit,
  });

  final BudgetRow budget;
  final String? categoryName;
  final String period;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: FutureBuilder<int>(
          future: services.transactions.spentForCategory(
            budget.categoryId,
            period,
          ),
          builder: (context, snapshot) {
            final spent = snapshot.data ?? 0;
            final limit = budget.amountMinor;
            final ratio = limit == 0 ? 0.0 : spent / limit;
            final over = spent > limit;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        categoryName ?? 'Category',
                        style: theme.textTheme.titleSmall,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 20),
                      onPressed: onEdit,
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
                  '${Money.format(spent)} of ${Money.format(limit)}'
                  '${over ? ' · over by ${Money.format(spent - limit)}' : ' · ${Money.format(limit - spent)} left'}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: over ? theme.colorScheme.error : null,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _BudgetEditorSheet extends StatefulWidget {
  const _BudgetEditorSheet({required this.period, this.existing});

  final String period;
  final BudgetRow? existing;

  @override
  State<_BudgetEditorSheet> createState() => _BudgetEditorSheetState();
}

class _BudgetEditorSheetState extends State<_BudgetEditorSheet> {
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
    final amountMinor = Money.tryParseToMinor(_amountController.text);
    if (_categoryId == null) {
      setState(() => _error = 'Pick a category');
      return;
    }
    if (amountMinor == null || amountMinor <= 0) {
      setState(() => _error = 'Enter a monthly limit like 1500');
      return;
    }
    final services = AppScope.of(context);
    final navigator = Navigator.of(context);
    await services.budgets.upsert(
      categoryId: _categoryId!,
      period: widget.period,
      amountMinor: amountMinor,
    );
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
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
          StreamBuilder<List<CategoryRow>>(
            stream: services.categories.watchAll(),
            builder: (context, snapshot) {
              final categories = snapshot.data ?? const <CategoryRow>[];
              return DropdownButtonFormField<String>(
                initialValue: categories.any((c) => c.id == _categoryId)
                    ? _categoryId
                    : null,
                decoration: const InputDecoration(labelText: 'Category'),
                items: [
                  for (final category in categories)
                    DropdownMenuItem(
                      value: category.id,
                      child: Text('${category.icon ?? ''} ${category.name}'),
                    ),
                ],
                onChanged: widget.existing != null
                    ? null
                    : (value) => setState(() => _categoryId = value),
              );
            },
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _amountController,
            decoration: const InputDecoration(
              labelText: 'Monthly limit',
              prefixText: 'ZMW ',
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp('[0-9.,]')),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 24),
          Row(
            children: [
              if (widget.existing != null)
                TextButton(
                  onPressed: () async {
                    final navigator = Navigator.of(context);
                    await services.budgets.delete(widget.existing!.id);
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

class _EmptyBudgets extends StatelessWidget {
  const _EmptyBudgets({required this.onAdd});

  final VoidCallback onAdd;

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
            FilledButton(onPressed: onAdd, child: const Text('Set a budget')),
          ],
        ),
      ),
    );
  }
}
