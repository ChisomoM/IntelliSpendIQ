import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intellispendiq/budgets/cubit/cubit.dart';
import 'package:intellispendiq/core/money.dart';
import 'package:intellispendiq/design/design.dart';
import 'package:intellispendiq/domain/models/category.dart';

/// Budgeted / spent / remaining, side by side.
///
/// Only "remaining" is coloured, and only when it has gone negative —
/// spending money is not an alarm, so a plain "Spent" figure stays in
/// the ordinary text colour. The old version rendered every tile the
/// same way and relied on the reader to notice a minus sign.
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
    final money = Theme.of(context).extension<MoneyColors>()!;
    final isOver = remainingMinor < 0;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: StatTile(
            label: 'Budgeted',
            value: MoneyText(budgetedMinor, size: MoneySize.meta),
          ),
        ),
        const SizedBox(width: Space.x1),
        Expanded(
          child: StatTile(
            label: 'Spent',
            value: MoneyText(spentMinor, size: MoneySize.meta),
          ),
        ),
        const SizedBox(width: Space.x1),
        Expanded(
          child: StatTile(
            label: isOver ? 'Over by' : 'Left',
            value: MoneyText(
              remainingMinor.abs(),
              size: MoneySize.meta,
              color: isOver ? money.outflow : null,
            ),
          ),
        ),
      ],
    );
  }
}

/// One subcategory row: spent against its own budget, or just spent
/// when it has none of its own.
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
    final colors = Theme.of(context).colorScheme;
    final money = Theme.of(context).extension<MoneyColors>()!;
    final hue = CategoryPalette.forCategory(
      categoryId: category.id,
      storedColor: category.color,
      brightness: Theme.of(context).brightness,
    );
    final budgeted = category.budgetedAmountMinor;
    final isOver = budgeted != null && spentMinor > budgeted;
    final percent = budgeted == null
        ? null
        : (budgeted == 0 ? 0 : (spentMinor / budgeted * 100))
              .clamp(0, 999)
              .toStringAsFixed(0);

    return Padding(
      padding: const EdgeInsets.only(bottom: Space.x1),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CategoryAvatar(
                  iconKey: category.icon,
                  categoryId: category.id,
                  colorName: category.color,
                  size: 32,
                ),
                const SizedBox(width: Space.x1),
                Expanded(
                  child: Text(
                    category.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.rowTitle(color: colors.onSurface),
                  ),
                ),
                const SizedBox(width: Space.x1),
                MoneyText(spentMinor, size: MoneySize.meta),
              ],
            ),
            if (budgeted == null) ...[
              const SizedBox(height: 6),
              Text(
                'No budget of its own',
                style: AppTypography.metadata(color: colors.onSurfaceVariant),
              ),
            ] else ...[
              const SizedBox(height: Space.x1),
              ProgressMeter(
                value: budgeted == 0 ? 0 : spentMinor / budgeted,
                isOver: isOver,
                height: 6,
                fillColor: hue.series,
              ),
              const SizedBox(height: 6),
              Text(
                isOver
                    ? '${Money.display(spentMinor - budgeted)} over '
                          '${Money.display(budgeted)} · $percent%'
                    : '${Money.display(budgeted - spentMinor)} left of '
                          '${Money.display(budgeted)} · $percent%',
                style: AppTypography.metadata(
                  color: isOver ? money.outflow : colors.onSurfaceVariant,
                ),
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
    return AppSheet.show<void>(
      context,
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
    final state = context.read<CategoryDetailCubit>().state;
    final targets = state.transferTargets;
    final colors = Theme.of(context).colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Move budget', style: AppTypography.sectionHeader()),
        const SizedBox(height: Space.x1),
        Text(
          'Takes from this category’s budget and adds it to another. '
          'Nothing you have already spent changes.',
          style: AppTypography.metadata(color: colors.onSurfaceVariant),
        ),
        const SizedBox(height: Space.x2),
        if (targets.isEmpty)
          Text(
            'There is no other category of the same type to move it to.',
            style: AppTypography.body(color: colors.onSurfaceVariant),
          )
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
          const SizedBox(height: Space.x2),
          AmountField(
            controller: _amountController,
            autofocus: true,
            errorText: _error,
          ),
          const SizedBox(height: Space.x3),
          AppButton.primary(label: 'Move', onPressed: _transfer),
        ],
      ],
    );
  }
}
