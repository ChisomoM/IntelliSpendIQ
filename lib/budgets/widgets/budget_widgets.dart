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

/// Screen title and its one-line promise, in the body rather than an
/// app bar — the title can then be display-sized instead of chrome-sized.
class BudgetsHeader extends StatelessWidget {
  const BudgetsHeader({required this.onAddCategory, super.key});

  final VoidCallback onAddCategory;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Budgets',
                style: AppTypography.screenTitle(color: colors.onSurface),
              ),
              const SizedBox(height: 2),
              Text(
                'Plan smart. Spend wisely.',
                style: AppTypography.metadata(color: colors.onSurfaceVariant),
              ),
            ],
          ),
        ),
        _RoundAction(icon: AppIcons.add, onTap: onAddCategory, tooltip: 'Add'),
      ],
    );
  }
}

/// A soft circular icon button — the tinted round `+` from the design
/// reference, rather than a bare app-bar glyph.
class _RoundAction extends StatelessWidget {
  const _RoundAction({
    required this.icon,
    required this.onTap,
    required this.tooltip,
  });

  final List<List<dynamic>> icon;
  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Tooltip(
      message: tooltip,
      child: Material(
        color: colors.primary.withValues(alpha: 0.10),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            width: Space.x6,
            height: Space.x6,
            child: Center(child: AppIcon(icon, size: 22, color: colors.primary)),
          ),
        ),
      ),
    );
  }
}

/// Chevron / pill / chevron period control.
///
/// The pill is the tappable target rather than a bare centred label, so
/// the window reads as something you can change, not a caption.
class PeriodPill extends StatelessWidget {
  const PeriodPill({
    required this.label,
    required this.onPrevious,
    required this.onNext,
    super.key,
  });

  final String label;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Row(
      children: [
        IconButton(
          onPressed: onPrevious,
          tooltip: 'Previous period',
          icon: AppIcon(AppIcons.chevronLeft, size: 20),
        ),
        Expanded(
          child: Container(
            height: Space.x6,
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? colors.surfaceContainerLow
                  : colors.surface,
              borderRadius: Radii.chipRadius,
              boxShadow: AppShadows.card(Theme.of(context).brightness),
            ),
            alignment: Alignment.center,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AppIcon(
                  AppIcons.calendar,
                  size: 18,
                  color: colors.onSurfaceVariant,
                ),
                const SizedBox(width: Space.x1),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.rowTitle(color: colors.onSurface),
                  ),
                ),
              ],
            ),
          ),
        ),
        IconButton(
          onPressed: onNext,
          tooltip: 'Next period',
          icon: AppIcon(AppIcons.chevronRight, size: 20),
        ),
      ],
    );
  }
}

/// The period's plan and what has been spent against it.
///
/// The three figures underneath — spent, left, days remaining — sit as
/// a row of equals, because each answers a different question and none
/// of them is the headline. The headline is the plan itself.
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
    if (plannedMinor <= 0) {
      return SetBudgetPrompt(
        onTap: () => OverallBudgetEditorSheet.show(context),
      );
    }

    const onSurface = AppColors.nightText;
    const onSurfaceMuted = AppColors.nightText2;
    // The hero is dark in both themes, so it takes the dark-mode money
    // colour regardless of brightness.
    const overColor = AppColors.outflowD;

    final isOver = totalSpent > plannedMinor;
    final leftMinor = plannedMinor - totalSpent;
    final allocationDelta = allocatedMinor - plannedMinor;
    final leftPercent = plannedMinor == 0
        ? 0
        : ((leftMinor / plannedMinor) * 100).clamp(0, 100).round();

    return HeroCard(
      onTap: () =>
          OverallBudgetEditorSheet.show(context, existing: overallBudget),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'TOTAL BUDGET',
            style: AppTypography.chipOverline(color: onSurfaceMuted),
          ),
          const SizedBox(height: Space.x1),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Flexible(
                child: MoneyText(
                  plannedMinor,
                  size: MoneySize.display,
                  color: onSurface,
                ),
              ),
              const SizedBox(width: Space.x1),
              AppIcon(AppIcons.edit, size: 18, color: onSurfaceMuted),
            ],
          ),
          const SizedBox(height: Space.x2),
          ProgressMeter(
            value: totalSpent / plannedMinor,
            isOver: isOver,
            onDarkSurface: true,
          ),
          const SizedBox(height: Space.x2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _HeroStat(
                  label: 'Spent',
                  value: Money.display(totalSpent),
                ),
              ),
              Expanded(
                child: _HeroStat(
                  label: isOver ? 'Over by' : 'Left',
                  value: Money.display(leftMinor.abs()),
                  tone: isOver ? overColor : null,
                ),
              ),
              Expanded(
                child: _HeroStat(
                  label: isCurrentPeriod ? 'Days left' : 'Period',
                  value: isCurrentPeriod
                      ? (daysLeft == 1 ? '1 day' : '$daysLeft days')
                      : 'Ended',
                  detail: isCurrentPeriod && !isOver ? '$leftPercent% left' : null,
                ),
              ),
            ],
          ),
          if (allocatedMinor > 0) ...[
            const SizedBox(height: Space.x2),
            Text(
              switch (allocationDelta) {
                0 => 'Every kwacha is allocated to a category',
                < 0 =>
                  '${Money.display(-allocationDelta)} not yet in a category',
                _ =>
                  'Categories add up to ${Money.display(allocationDelta)} '
                      'more than the budget',
              },
              style: AppTypography.metadata(
                color: allocationDelta > 0 ? overColor : onSurfaceMuted,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({
    required this.label,
    required this.value,
    this.detail,
    this.tone,
  });

  final String label;
  final String value;
  final String? detail;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: AppTypography.metadata(color: AppColors.nightText2),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: AppTypography.rowAmount(color: tone ?? AppColors.nightText),
        ),
        if (detail != null)
          Text(
            detail!,
            style: AppTypography.metadata(color: AppColors.nightText2),
          ),
      ],
    );
  }
}

/// Shown in the hero's place until a budget exists.
class SetBudgetPrompt extends StatelessWidget {
  const SetBudgetPrompt({required this.onTap, super.key});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return AppCard(
      child: Row(
        children: [
          Container(
            width: Space.x6,
            height: Space.x6,
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: AppIcon(AppIcons.budgets, size: 22, color: colors.primary),
          ),
          const SizedBox(width: Space.x2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Set your total budget', style: AppTypography.rowTitle()),
                const SizedBox(height: 2),
                Text(
                  'Your overall plan for this period. Change it any time.',
                  style: AppTypography.metadata(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: Space.x1),
          FilledButton(onPressed: onTap, child: const Text('Set')),
        ],
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

/// A top-level expense category with a budget set.
///
/// Laid out to be scannable down a column: avatar and name on the left,
/// the limit and what is left stacked on the right, and the meter
/// spanning underneath in the category's own hue.
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
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                CategoryAvatar(
                  iconKey: category.icon,
                  categoryId: category.id,
                  colorName: category.color,
                  size: 44,
                ),
                const SizedBox(width: Space.x2),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        category.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.rowTitle(color: colors.onSurface),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${Money.display(spentMinor)} spent',
                        style: AppTypography.metadata(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: Space.x1),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    MoneyText(limit, size: MoneySize.meta),
                    const SizedBox(height: 2),
                    // Over-budget is said, not merely coloured — roughly
                    // one man in twelve here cannot rely on red/green.
                    Text(
                      isOver
                          ? '${Money.display(spentMinor - limit)} over'
                          : '${Money.display(limit - spentMinor)} left',
                      style: AppTypography.metadata(
                        color: isOver ? money.outflow : money.inflow,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: Space.x2),
            ProgressMeter(
              value: limit == 0 ? 0 : spentMinor / limit,
              isOver: isOver,
              height: 6,
              fillColor: hue.series,
            ),
          ],
        ),
      ),
    );
  }
}

/// Full-width dashed-feeling "add" row that closes the category list.
class AddCategoryCard extends StatelessWidget {
  const AddCategoryCard({required this.onTap, super.key});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      borderRadius: Radii.cardRadius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            borderRadius: Radii.cardRadius,
            border: Border.all(color: colors.outlineVariant),
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AppIcon(AppIcons.add, size: 18, color: colors.primary),
              const SizedBox(width: Space.x1),
              Text(
                'Add category',
                style: AppTypography.rowTitle(color: colors.primary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The assistant's read on the period, as a tinted strip at the end of
/// the screen.
///
/// Deliberately a single sentence with a way in, not a panel: it is a
/// prompt to look closer, and anything longer would compete with the
/// figures it is commenting on.
class BudgetInsightCard extends StatelessWidget {
  const BudgetInsightCard({
    required this.message,
    required this.onOpen,
    super.key,
  });

  final String message;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Material(
      color: colors.primary.withValues(alpha: 0.07),
      borderRadius: Radii.cardRadius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(Space.cardPadding),
          child: Row(
            children: [
              AppIcon(AppIcons.assistant, size: 20, color: colors.primary),
              const SizedBox(width: Space.x2),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Insight',
                      style: AppTypography.chipOverline(color: colors.primary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      message,
                      style: AppTypography.body(color: colors.onSurface),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: Space.x1),
              AppIcon(
                AppIcons.chevronRight,
                size: 20,
                color: colors.onSurfaceVariant,
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
