import 'package:flutter/material.dart';
import 'package:intellispendiq/core/money.dart';
import 'package:intellispendiq/design/design.dart';
import 'package:intellispendiq/domain/services/shopping_trip_calculator.dart';

/// The one big number for the trip: what is left to spend, or how far
/// over. Every state is said in words as well as colour.
class TripHeroCard extends StatelessWidget {
  const TripHeroCard({
    required this.summary,
    required this.categoryName,
    super.key,
  });

  final TripSummary summary;
  final String Function(String? categoryId) categoryName;

  @override
  Widget build(BuildContext context) {
    const onSurface = AppColors.nightText;
    const muted = AppColors.nightText2;

    final hasBudget = summary.lines.any((l) => l.onList && l.hasBudget);
    final isOver = summary.isOver;
    final budget = summary.budgetMinor;
    final used = budget <= 0
        ? 0.0
        : ((budget - summary.leftMinor) / budget).clamp(0.0, 1.0);

    final label = isOver
        ? 'OVER BUDGET'
        : hasBudget
        ? 'LEFT TO SPEND'
        : 'IN YOUR CART';
    final amount = isOver
        ? summary.overByMinor
        : hasBudget
        ? summary.leftMinor
        : summary.cartTotalMinor;

    return HeroCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTypography.chipOverline(color: muted)),
          const SizedBox(height: Space.x1),
          MoneyText(
            amount,
            size: MoneySize.display,
            color: isOver ? AppColors.outflowD : onSurface,
          ),
          if (hasBudget) ...[
            const SizedBox(height: Space.x2),
            ProgressMeter(value: used, isOver: isOver, onDarkSurface: true),
          ],
          const SizedBox(height: Space.x1),
          Text(
            hasBudget
                ? '${Money.display(summary.cartTotalMinor)} in cart of '
                      '${Money.display(budget)} trip budget'
                : 'No budget set for what is on this trip',
            style: AppTypography.metadata(color: muted),
          ),
          if (hasBudget || isOver) ...[
            const SizedBox(height: Space.x1),
            _StatusLine(summary: summary, categoryName: categoryName),
          ],
          const SizedBox(height: Space.x2),
          Row(
            children: [
              Expanded(
                child: _Stat(
                  label: 'IMPULSE',
                  amount: summary.impulseMinor,
                  caption: summary.cartTotalMinor == 0
                      ? null
                      : '${(summary.impulseShare * 100).round()}% of cart',
                ),
              ),
              Expanded(
                child: _Stat(
                  label: 'STILL TO BUY',
                  amount: summary.toBuyMinor,
                  caption: summary.toBuyMinor == 0 ? 'all picked up' : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.summary, required this.categoryName});

  final TripSummary summary;
  final String Function(String? categoryId) categoryName;

  @override
  Widget build(BuildContext context) {
    final over = summary.overLines;
    final (text, tone) = over.isNotEmpty
        ? (
            over.length == 1
                ? '${Money.display(over.first.overByMinor)} over in '
                      '${categoryName(over.first.categoryId)}'
                : 'Over in ${over.length} categories',
            AppColors.outflowD,
          )
        : summary.severity == TripSeverity.near
        ? ('Nearing a limit', AppColors.reviewD)
        : ('Under budget', AppColors.inflowD);

    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: tone, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            text,
            style: AppTypography.rowTitle(color: tone),
          ),
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.amount, this.caption});

  final String label;
  final int amount;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.chipOverline(color: AppColors.nightText2),
        ),
        const SizedBox(height: 4),
        MoneyText(amount, color: AppColors.nightText),
        if (caption != null)
          Text(
            caption!,
            style: AppTypography.metadata(color: AppColors.nightText2),
          ),
      ],
    );
  }
}
