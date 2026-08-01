import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intellispendiq/budgets/cubit/cubit.dart';
import 'package:intellispendiq/budgets/view/category_detail_page.dart';
import 'package:intellispendiq/categories/widgets/widgets.dart';
import 'package:intellispendiq/core/money.dart';
import 'package:intellispendiq/design/design.dart';
import 'package:intellispendiq/domain/models/category.dart';
import 'package:intellispendiq/domain/models/enums.dart';
import 'package:intellispendiq/domain/models/overall_budget.dart';

/// The period's plan and what has been spent against it, on a dark card
/// in both themes — the screen's one headline figure.
///
/// "Planned" is the overall target; "Allocated" is the sum of the
/// category envelopes underneath. They are different questions and
/// used to be shown as peer figures with no indication of which one
/// the progress bar tracked.
class BudgetHeroCard extends StatelessWidget {
  const BudgetHeroCard({
    required this.plannedMinor,
    required this.totalSpent,
    required this.allocatedMinor,
    required this.daysLeft,
    required this.isCurrentPeriod,
    this.overallBudget,
    super.key,
  });

  final int plannedMinor;
  final int totalSpent;
  final int allocatedMinor;
  final int daysLeft;
  final bool isCurrentPeriod;
  final OverallBudget? overallBudget;

  @override
  Widget build(BuildContext context) {
    final hasPlanned = plannedMinor > 0;

    if (!hasPlanned) {
      return AppCard(
        onTap: () => OverallBudgetEditorSheet.show(context),
        child: Row(
          children: [
            AppIcon(
              AppIcons.budgets,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: Space.x2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Set your budget for this period',
                    style: AppTypography.rowTitle(),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'How much you plan to spend in total. You can change '
                    'it any time.',
                    style: AppTypography.metadata(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            AppIcon(AppIcons.chevronRight, size: 20),
          ],
        ),
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? AppColors.night800 : AppColors.ink900;
    const onSurface = AppColors.nightText;
    const onSurfaceMuted = AppColors.nightText2;
    // Dark in both themes, so it takes the dark-mode money colour
    // regardless of brightness — light mode's outflow would be a dark
    // red on near-black.
    const overColor = AppColors.outflowD;

    final isOver = totalSpent > plannedMinor;
    final allocationDelta = allocatedMinor - plannedMinor;
    final tail = isCurrentPeriod
        ? ', ${daysLeft == 1 ? '1 day' : '$daysLeft days'} left'
        : '';

    return Material(
      color: surface,
      borderRadius: Radii.cardRadius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () =>
            OverallBudgetEditorSheet.show(context, existing: overallBudget),
        child: Padding(
          padding: const EdgeInsets.all(Space.cardPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'BUDGET FOR THIS PERIOD',
                      style: AppTypography.chipOverline(
                        color: onSurfaceMuted,
                      ),
                    ),
                  ),
                  AppIcon(AppIcons.edit, size: 18, color: onSurfaceMuted),
                ],
              ),
              const SizedBox(height: Space.x1),
              MoneyText(
                plannedMinor,
                size: MoneySize.display,
                color: onSurface,
              ),
              const SizedBox(height: Space.x2),
              ProgressMeter(
                value: totalSpent / plannedMinor,
                isOver: isOver,
                onDarkSurface: true,
              ),
              const SizedBox(height: Space.x1),
              Text(
                isOver
                    ? '${Money.display(totalSpent - plannedMinor)} over'
                          '$tail'
                    : '${Money.display(totalSpent)} spent, '
                          '${Money.display(plannedMinor - totalSpent)} left'
                          '$tail',
                style: AppTypography.metadata(
                  color: isOver ? overColor : onSurfaceMuted,
                ),
              ),
              if (allocatedMinor > 0) ...[
                const SizedBox(height: 4),
                Text(
                  switch (allocationDelta) {
                    0 => 'Every kwacha is allocated to a category',
                    < 0 =>
                      '${Money.display(-allocationDelta)} not yet in a '
                          'category',
                    _ =>
                      'Categories add up to '
                          '${Money.display(allocationDelta)} more than the '
                          'budget',
                  },
                  style: AppTypography.metadata(
                    color: allocationDelta > 0 ? overColor : onSurfaceMuted,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Create or edit the period's overall budget, independent of category
/// limits. Hosted by the page's [BudgetsCubit].
class OverallBudgetEditorSheet extends StatefulWidget {
  const OverallBudgetEditorSheet({this.existing, super.key});

  final OverallBudget? existing;

  static Future<void> show(BuildContext context, {OverallBudget? existing}) {
    final cubit = context.read<BudgetsCubit>();
    return AppSheet.show<void>(
      context,
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
    await context.read<BudgetsCubit>().setOverallBudget(_amountController.text);
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

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          isEditing ? 'Edit budget' : 'Set budget',
          style: AppTypography.sectionHeader(),
        ),
        const SizedBox(height: Space.x1),
        Text(
          'How much you plan to spend in total this period.',
          style: AppTypography.metadata(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: Space.x2),
        AmountField(
          controller: _amountController,
          autofocus: true,
          errorText: _error,
        ),
        const SizedBox(height: Space.x3),
        Row(
          children: [
            if (isEditing)
              TextButton(onPressed: _delete, child: const Text('Remove')),
            const Spacer(),
            FilledButton(onPressed: _save, child: const Text('Save')),
          ],
        ),
      ],
    );
  }
}

/// A top-level expense category with a budget set. Tapping opens its
/// detail page — subcategories, transfer, the full breakdown.
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
    final colors = Theme.of(context).colorScheme;
    final money = Theme.of(context).extension<MoneyColors>()!;
    final hue = CategoryPalette.forCategory(
      categoryId: category.id,
      storedColor: category.color,
      brightness: Theme.of(context).brightness,
    );
    final limit = category.budgetedAmountMinor!;
    final isOver = spentMinor > limit;

    return Padding(
      padding: const EdgeInsets.only(bottom: Space.x1),
      child: AppCard(
        onTap: () => Navigator.of(context).push<void>(
          CategoryDetailPage.route(
            categoryId: category.id,
            periodId: periodId,
            periodStartAt: periodStartAt,
            periodEndAt: periodEndAt,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CategoryAvatar(
                  iconKey: category.icon,
                  categoryId: category.id,
                  colorName: category.color,
                  size: 36,
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
                MoneyText(limit, size: MoneySize.meta),
              ],
            ),
            const SizedBox(height: Space.x1),
            ProgressMeter(
              value: limit == 0 ? 0 : spentMinor / limit,
              isOver: isOver,
              height: 6,
              fillColor: hue.series,
            ),
            const SizedBox(height: 6),
            // Over-budget is stated, not just coloured — roughly one in
            // twelve men here cannot rely on the red/green distinction.
            Text(
              isOver
                  ? '${Money.display(spentMinor - limit)} over'
                  : '${Money.display(spentMinor)} spent, '
                        '${Money.display(limit - spentMinor)} left',
              style: AppTypography.metadata(
                color: isOver ? money.outflow : colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class NoBudgetsYet extends StatelessWidget {
  const NoBudgetsYet({super.key});

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: AppIcons.emptyWallet,
      title: 'No category budgets yet',
      message: 'Give a category an amount and this screen will track '
          'your spending against it.',
      actionLabel: 'Add a category budget',
      onAction: () => Navigator.of(context).push<String?>(
        CategoryEditorPage.route(initialType: CategoryType.expense),
      ),
    );
  }
}
