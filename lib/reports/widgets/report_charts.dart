import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intellispendiq/core/money.dart';
import 'package:intellispendiq/data/repositories/transaction_repository.dart';
import 'package:intellispendiq/design/design.dart';

/// One arc of the breakdown donut.
class DonutSlice {
  const DonutSlice({
    required this.label,
    required this.amountMinor,
    this.entityId,
    this.colorName,
  });

  final String label;
  final int amountMinor;

  /// The category or account this arc is, so its colour follows the
  /// entity rather than its rank. Without it, filtering or a change in
  /// spend would repaint every surviving arc.
  final String? entityId;

  /// `Category.color`, when the user has pinned one.
  final String? colorName;
}

/// Spend composition as a donut with a labelled legend.
///
/// The palette used to be raw Material colours — `Colors.teal`,
/// `Colors.indigo`, `Colors.deepPurple` … — cycled with `%`, so two
/// categories could share a colour, and two of the eight collided with
/// the brand violet the buttons use. Arcs now come from
/// [CategoryPalette], which is validated for colour-vision separation
/// against this app's own surfaces.
///
/// Past [_maxSlices] the remainder folds into a single neutral "Other"
/// arc rather than inventing hues: the palette's guarantees only hold
/// for the slots it actually defines.
class SpendDonutChart extends StatelessWidget {
  const SpendDonutChart({required this.slices, super.key});

  final List<DonutSlice> slices;

  static const _maxSlices = 5;

  @override
  Widget build(BuildContext context) {
    if (slices.isEmpty) return const SizedBox.shrink();
    final colors = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;
    final total = slices.fold<int>(0, (sum, slice) => sum + slice.amountMinor);

    final sorted = [...slices]
      ..sort((a, b) => b.amountMinor.compareTo(a.amountMinor));
    final head = sorted.take(_maxSlices).toList();
    final tailTotal = sorted
        .skip(_maxSlices)
        .fold<int>(0, (sum, slice) => sum + slice.amountMinor);

    Color colorOf(DonutSlice slice) => CategoryPalette.forCategory(
      categoryId: slice.entityId ?? slice.label,
      storedColor: slice.colorName,
      brightness: brightness,
    ).series;

    final entries = <(String, int, Color)>[
      for (final slice in head)
        (slice.label, slice.amountMinor, colorOf(slice)),
      if (tailTotal > 0)
        ('Everything else', tailTotal, colors.surfaceContainerHigh),
    ];

    return Column(
      children: [
        SizedBox(
          height: 196,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PieChart(
                PieChartData(
                  // A surface-coloured gap keeps neighbouring arcs
                  // separable instead of blending at the seam.
                  sectionsSpace: 2,
                  centerSpaceRadius: 62,
                  sections: [
                    for (final (_, amount, color) in entries)
                      PieChartSectionData(
                        value: amount.toDouble(),
                        color: color,
                        showTitle: false,
                        radius: 26,
                      ),
                  ],
                ),
              ),
              // The hole was empty. The total belongs in it — it is the
              // one number the whole chart is a decomposition of.
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'TOTAL',
                    style: AppTypography.chipOverline(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 2),
                  MoneyText(total, size: MoneySize.row),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: Space.x2),
        for (final (index, entry) in entries.indexed) ...[
          if (index > 0) const SizedBox(height: Space.x1),
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: entry.$3,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: Space.x1),
              Expanded(
                // Identity is never colour alone: every arc is named
                // here, and the label wears text colour, not the arc's.
                child: Text(
                  entry.$1,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.body(color: colors.onSurface),
                ),
              ),
              const SizedBox(width: Space.x1),
              Text(
                total == 0 ? '0%' : '${(entry.$2 / total * 100).round()}%',
                style: AppTypography.metadata(color: colors.onSurfaceVariant),
              ),
              const SizedBox(width: Space.x2),
              MoneyText(entry.$2, size: MoneySize.meta),
            ],
          ),
        ],
      ],
    );
  }
}

/// Confirmed spend for the trailing months, oldest first.
class MonthTrendChart extends StatelessWidget {
  const MonthTrendChart({required this.trend, super.key});

  final List<MonthSpend> trend;

  static const _monthNames = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  static String _monthLabel(String period) =>
      _monthNames[int.parse(period.split('-')[1]) - 1];

  @override
  Widget build(BuildContext context) {
    if (trend.isEmpty) return const SizedBox.shrink();
    final colors = Theme.of(context).colorScheme;
    final maxSpend = trend
        .map((month) => month.spentMinor)
        .reduce((a, b) => a > b ? a : b);
    final maxY = maxSpend == 0 ? 100.0 : maxSpend * 1.25;

    return SizedBox(
      height: 196,
      child: BarChart(
        BarChartData(
          maxY: maxY,
          alignment: BarChartAlignment.spaceAround,
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, _, rod, _) => BarTooltipItem(
                Money.display(rod.toY.round()),
                AppTypography.metaAmount(color: colors.surface),
              ),
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
                  final index = value.toInt();
                  if (index < 0 || index >= trend.length) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      _monthLabel(trend[index].period),
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
            for (final (index, month) in trend.indexed)
              BarChartGroupData(
                x: index,
                barRods: [
                  BarChartRodData(
                    toY: month.spentMinor.toDouble(),
                    // One series, so the brand colour carries it and no
                    // legend is needed — the section title names it.
                    color: colors.primary,
                    width: 14,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(4),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// A month grid shaded by how much was spent each day.
class SpendCalendarHeatmap extends StatelessWidget {
  const SpendCalendarHeatmap({
    required this.period,
    required this.dailySpend,
    required this.maxDailyMinor,
    required this.onDayTap,
    super.key,
  });

  final String period;
  final List<DailySpend> dailySpend;
  final int maxDailyMinor;
  final ValueChanged<DateTime> onDayTap;

  @override
  Widget build(BuildContext context) {
    final parts = period.split('-');
    final year = int.parse(parts[0]);
    final month = int.parse(parts[1]);
    final daysInMonth = DateTime(year, month + 1, 0).day;
    // 1 = Monday .. 7 = Sunday, so the grid's first cell lines up under
    // the right weekday header.
    final leadingBlanks = DateTime(year, month).weekday - 1;
    final colors = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;
    final byDay = {
      for (final entry in dailySpend) entry.date.day: entry.spentMinor,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            for (final label in const ['M', 'T', 'W', 'T', 'F', 'S', 'S'])
              Expanded(
                child: Center(
                  child: Text(
                    label,
                    style: AppTypography.metadata(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: Space.x1),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
          ),
          itemCount: daysInMonth + leadingBlanks,
          itemBuilder: (context, index) {
            final dayNumber = index - leadingBlanks + 1;
            if (dayNumber < 1) return const SizedBox.shrink();
            final spent = byDay[dayNumber];
            final hasSpend = spent != null && spent > 0;
            final intensity = !hasSpend || maxDailyMinor == 0
                ? 0.0
                : (spent / maxDailyMinor).clamp(0.0, 1.0);
            final fill = hasSpend
                ? CategoryPalette.sequential(intensity, brightness)
                : colors.surfaceContainerHigh;
            // The deeper half of the ramp needs light ink on it; the
            // pale end needs dark. Picking by intensity keeps the day
            // number legible across the whole scale.
            final ink = !hasSpend
                ? colors.onSurfaceVariant
                : (brightness == Brightness.dark
                      ? (intensity > 0.6
                            ? AppColors.ink900
                            : AppColors.nightText)
                      : (intensity > 0.5
                            ? AppColors.paper
                            : AppColors.ink900));

            return Padding(
              padding: const EdgeInsets.all(2),
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => onDayTap(DateTime(year, month, dayNumber)),
                child: Container(
                  decoration: BoxDecoration(
                    color: fill,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '$dayNumber',
                    style: AppTypography.metaAmount(color: ink),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
