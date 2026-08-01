import 'package:flutter/material.dart';
import 'package:intellispendiq/design/theme/money_colors.dart';
import 'package:intellispendiq/design/tokens/typography.dart';

/// A circular percent-spent gauge with the figure in the middle.
///
/// The percentage never animates — the brand guide forbids animating
/// an amount, and a counting-up percentage is the same lie about a
/// number that is already known.
class MoneyGauge extends StatelessWidget {
  const MoneyGauge({
    required this.spentMinor,
    required this.budgetedMinor,
    this.size = 148,
    this.caption = 'of budget spent',
    this.arcColor,
    super.key,
  });

  final int spentMinor;
  final int budgetedMinor;
  final double size;
  final String caption;

  /// The arc's colour when the thing being measured has one of its own
  /// — a category gauge wears the category's hue. Overspend still wins.
  final Color? arcColor;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final money = Theme.of(context).extension<MoneyColors>()!;

    final ratio = budgetedMinor == 0 ? 0.0 : spentMinor / budgetedMinor;
    final isOver = budgetedMinor > 0 && spentMinor > budgetedMinor;
    final percent = (ratio * 100).clamp(0, 999).toStringAsFixed(0);

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              value: ratio.clamp(0.0, 1.0),
              strokeWidth: 10,
              strokeCap: StrokeCap.round,
              backgroundColor: colors.surfaceContainerHigh,
              valueColor: AlwaysStoppedAnimation<Color>(
                isOver ? money.outflow : (arcColor ?? colors.primary),
              ),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$percent%',
                style: AppTypography.rowAmount(
                  color: isOver ? money.outflow : colors.onSurface,
                ).copyWith(fontSize: 28, height: 1.1),
              ),
              const SizedBox(height: 2),
              Text(
                caption,
                textAlign: TextAlign.center,
                style: AppTypography.metadata(color: colors.onSurfaceVariant),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
