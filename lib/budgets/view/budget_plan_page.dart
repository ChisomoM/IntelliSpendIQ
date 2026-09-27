import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intellispendiq/core/money.dart';
import 'package:intellispendiq/design/design.dart';
import 'package:intellispendiq/domain/models/category.dart';
import 'package:intellispendiq/reports/widgets/widgets.dart';

/// Planned income vs. planned expenses for a budget period — the plan
/// itself, not what has actually landed or been spent yet. Reports
/// already covers confirmed activity; this is the forecast behind it.
class BudgetPlanPage extends StatelessWidget {
  const BudgetPlanPage({
    required this.periodLabel,
    required this.plannedIncomeMinor,
    required this.plannedExpenseMinor,
    required this.expenseCategories,
    super.key,
  });

  final String periodLabel;
  final int plannedIncomeMinor;
  final int plannedExpenseMinor;

  /// Top-level expense categories with a budget assigned, for the
  /// per-category breakdown below the comparison.
  final List<Category> expenseCategories;

  static Route<void> route({
    required String periodLabel,
    required int plannedIncomeMinor,
    required int plannedExpenseMinor,
    required List<Category> expenseCategories,
  }) {
    return MaterialPageRoute<void>(
      builder: (_) => BudgetPlanPage(
        periodLabel: periodLabel,
        plannedIncomeMinor: plannedIncomeMinor,
        plannedExpenseMinor: plannedExpenseMinor,
        expenseCategories: expenseCategories,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final money = Theme.of(context).extension<MoneyColors>()!;
    final differenceMinor = plannedIncomeMinor - plannedExpenseMinor;
    final isShortfall = differenceMinor < 0;
    final allocationRatio = plannedIncomeMinor == 0
        ? 0.0
        : plannedExpenseMinor / plannedIncomeMinor;

    final slices = [
      for (final category in expenseCategories)
        if (category.hasBudget && category.budgetedAmountMinor! > 0)
          DonutSlice(
            label: category.name,
            amountMinor: category.budgetedAmountMinor!,
            entityId: category.id,
            colorName: category.color,
          ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('The plan')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            Space.gutter,
            Space.x1,
            Space.gutter,
            Space.x4,
          ),
          children: [
            _PlanHero(
              periodLabel: periodLabel,
              plannedIncomeMinor: plannedIncomeMinor,
              plannedExpenseMinor: plannedExpenseMinor,
              differenceMinor: differenceMinor,
              allocationRatio: allocationRatio,
            ),
            const SizedBox(height: Space.x3),
            _PlanInsightBanner(
              plannedIncomeMinor: plannedIncomeMinor,
              differenceMinor: differenceMinor,
              isShortfall: isShortfall,
            ),
            const SizedBox(height: Space.sectionGap),
            const SectionHeader(
              title: 'Income vs. expenses',
              subtitle: 'What the plan sets aside on each side',
            ),
            AppCard(
              child: _PlanBarChart(
                plannedIncomeMinor: plannedIncomeMinor,
                plannedExpenseMinor: plannedExpenseMinor,
                money: money,
              ),
            ),
            if (slices.isNotEmpty) ...[
              const SizedBox(height: Space.sectionGap),
              const SectionHeader(
                title: 'Planned by category',
                subtitle: 'How the allocated expense budget is split',
              ),
              const SizedBox(height: Space.x1),
              AppCard(child: SpendDonutChart(slices: slices)),
            ],
          ],
        ),
      ),
    );
  }
}

/// The headline: a gradient card in the same family as the Budgets
/// hero, so this page reads as a continuation of it rather than a
/// separate report bolted on. The gauge visualises the one relationship
/// the whole page is about — how much of planned income the plan
/// commits to expenses.
class _PlanHero extends StatelessWidget {
  const _PlanHero({
    required this.periodLabel,
    required this.plannedIncomeMinor,
    required this.plannedExpenseMinor,
    required this.differenceMinor,
    required this.allocationRatio,
  });

  final String periodLabel;
  final int plannedIncomeMinor;
  final int plannedExpenseMinor;
  final int differenceMinor;
  final double allocationRatio;

  @override
  Widget build(BuildContext context) {
    const onSurface = AppColors.nightText;
    const onSurfaceMuted = AppColors.nightText2;
    const overColor = AppColors.outflowD;
    final isShortfall = differenceMinor < 0;

    return HeroCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      periodLabel.toUpperCase(),
                      style: AppTypography.chipOverline(
                        color: onSurfaceMuted,
                      ),
                    ),
                    const SizedBox(height: Space.x1),
                    Text(
                      isShortfall ? 'Shortfall' : 'Surplus',
                      style: AppTypography.metadata(color: onSurfaceMuted),
                    ),
                    MoneyText(
                      differenceMinor.abs(),
                      size: MoneySize.display,
                      color: isShortfall ? overColor : onSurface,
                    ),
                  ],
                ),
              ),
              MoneyGauge(
                spentMinor: plannedExpenseMinor,
                budgetedMinor: plannedIncomeMinor,
                size: 92,
                caption: 'of income\nplanned away',
                arcColor: AppColors.violet300,
              ),
            ],
          ),
          const SizedBox(height: Space.x3),
          ProgressMeter(
            value: allocationRatio,
            isOver: isShortfall,
            onDarkSurface: true,
          ),
          const SizedBox(height: Space.x2),
          Row(
            children: [
              Expanded(
                child: _HeroFigure(
                  icon: AppIcons.moneyIn,
                  iconColor: AppColors.inflowD,
                  label: 'Planned income',
                  valueMinor: plannedIncomeMinor,
                ),
              ),
              const SizedBox(width: Space.x2),
              Expanded(
                child: _HeroFigure(
                  icon: AppIcons.moneyOut,
                  iconColor: AppColors.outflowD,
                  label: 'Planned expenses',
                  valueMinor: plannedExpenseMinor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroFigure extends StatelessWidget {
  const _HeroFigure({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.valueMinor,
  });

  final List<List<dynamic>> icon;
  final Color iconColor;
  final String label;
  final int valueMinor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: AppIcon(icon, size: 16, color: iconColor),
        ),
        const SizedBox(width: Space.x1),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.metadata(color: AppColors.nightText2),
              ),
              MoneyText(
                valueMinor,
                size: MoneySize.meta,
                color: AppColors.nightText,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A one-line read on the plan, in the same tinted-strip language as
/// the Budgets screen's insight card — quiet, but present, rather than
/// leaving the numbers above to speak for themselves.
class _PlanInsightBanner extends StatelessWidget {
  const _PlanInsightBanner({
    required this.plannedIncomeMinor,
    required this.differenceMinor,
    required this.isShortfall,
  });

  final int plannedIncomeMinor;
  final int differenceMinor;
  final bool isShortfall;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final money = Theme.of(context).extension<MoneyColors>()!;

    final String message;
    final Color tone;
    final List<List<dynamic>> icon;
    if (plannedIncomeMinor == 0) {
      message = 'No income planned for this period yet — add an income '
          'envelope on Budgets to see how the plan balances.';
      tone = colors.primary;
      icon = AppIcons.insights;
    } else if (isShortfall) {
      message = 'Categories are planned to spend '
          '${Money.display(differenceMinor.abs())} more than the income '
          'planned in — worth trimming a category or two.';
      tone = money.outflow;
      icon = AppIcons.moneyOut;
    } else if (differenceMinor == 0) {
      message = 'Every kwacha of planned income is spoken for.';
      tone = colors.primary;
      icon = AppIcons.check;
    } else {
      message = '${Money.display(differenceMinor)} of planned income is '
          'not yet assigned to a category.';
      tone = money.inflow;
      icon = AppIcons.moneyIn;
    }

    return Material(
      color: tone.withValues(alpha: 0.08),
      borderRadius: Radii.cardRadius,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(Space.cardPadding),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppIcon(icon, size: 20, color: tone),
            const SizedBox(width: Space.x2),
            Expanded(
              child: Text(message, style: AppTypography.body(color: colors.onSurface)),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanBarChart extends StatelessWidget {
  const _PlanBarChart({
    required this.plannedIncomeMinor,
    required this.plannedExpenseMinor,
    required this.money,
  });

  final int plannedIncomeMinor;
  final int plannedExpenseMinor;
  final MoneyColors money;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final maxAmount = plannedIncomeMinor > plannedExpenseMinor
        ? plannedIncomeMinor
        : plannedExpenseMinor;
    final maxY = maxAmount == 0 ? 100.0 : maxAmount * 1.25;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 196,
          child: BarChart(
            BarChartData(
              maxY: maxY,
              alignment: BarChartAlignment.spaceEvenly,
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipItem: (group, _, rod, _) {
                    final label = group.x == 0 ? 'Income' : 'Expenses';
                    return BarTooltipItem(
                      '$label\n${Money.display(rod.toY.round())}',
                      AppTypography.metaAmount(color: colors.surface),
                    );
                  },
                ),
              ),
              titlesData: FlTitlesData(
                leftTitles: const AxisTitles(),
                rightTitles: const AxisTitles(),
                topTitles: const AxisTitles(),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    getTitlesWidget: (value, meta) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          value == 0 ? 'Income' : 'Expenses',
                          style: AppTypography.metadata(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              barGroups: [
                BarChartGroupData(
                  x: 0,
                  barRods: [
                    BarChartRodData(
                      toY: plannedIncomeMinor.toDouble(),
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          money.inflow.withValues(alpha: 0.7),
                          money.inflow,
                        ],
                      ),
                      width: 44,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(10),
                      ),
                    ),
                  ],
                ),
                BarChartGroupData(
                  x: 1,
                  barRods: [
                    BarChartRodData(
                      toY: plannedExpenseMinor.toDouble(),
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          money.outflow.withValues(alpha: 0.7),
                          money.outflow,
                        ],
                      ),
                      width: 44,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(10),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
