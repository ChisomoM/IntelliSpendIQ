import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intellispendiq/core/money.dart';
import 'package:intellispendiq/data/repositories/transaction_repository.dart';

/// Fixed categorical palette, independent of the app theme so chart
/// slices stay distinguishable in both light and dark mode.
const List<Color> chartPalette = [
  Colors.teal,
  Colors.indigo,
  Colors.orange,
  Colors.pink,
  Colors.green,
  Colors.deepPurple,
  Colors.blue,
  Colors.amber,
];

class DonutSlice {
  const DonutSlice({required this.label, required this.amountMinor});

  final String label;
  final int amountMinor;
}

/// A donut chart with a colored legend underneath. Used for both the
/// category and account breakdowns — same shape of data, different
/// grouping.
class SpendDonutChart extends StatelessWidget {
  const SpendDonutChart({required this.slices, super.key});

  final List<DonutSlice> slices;

  @override
  Widget build(BuildContext context) {
    if (slices.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final total = slices.fold<int>(0, (sum, slice) => sum + slice.amountMinor);

    return Column(
      children: [
        SizedBox(
          height: 180,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 48,
              sections: [
                for (final (index, slice) in slices.indexed)
                  PieChartSectionData(
                    value: slice.amountMinor.toDouble(),
                    color: chartPalette[index % chartPalette.length],
                    showTitle: false,
                    radius: 48,
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        for (final (index, slice) in slices.indexed)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: chartPalette[index % chartPalette.length],
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(slice.label, style: theme.textTheme.bodyMedium),
                ),
                Text(
                  Money.format(slice.amountMinor),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 44,
                  child: Text(
                    '${total == 0 ? 0 : (slice.amountMinor / total * 100).round()}%',
                    textAlign: TextAlign.end,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// A row in the exact-figures list under the donut: label, amount,
/// share of total, and a bar scaled to the largest entry.
class SpendListRow extends StatelessWidget {
  const SpendListRow({
    required this.label,
    required this.amountMinor,
    required this.share,
    required this.barWidth,
    super.key,
  });

  final String label;
  final int amountMinor;
  final double share;
  final double barWidth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(label, style: theme.textTheme.bodyMedium),
              ),
              Text(
                Money.format(amountMinor),
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 44,
                child: Text(
                  '${(share * 100).round()}%',
                  textAlign: TextAlign.end,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          LinearProgressIndicator(value: barWidth),
        ],
      ),
    );
  }
}

/// Bar chart of confirmed spend for the trailing months in [trend],
/// oldest first — independent of the month the user is currently
/// drilled into above.
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
    final theme = Theme.of(context);
    final maxSpend = trend
        .map((month) => month.spentMinor)
        .reduce((a, b) => a > b ? a : b);
    final maxY = maxSpend == 0 ? 100.0 : maxSpend * 1.2;

    return SizedBox(
      height: 180,
      child: BarChart(
        BarChartData(
          maxY: maxY,
          alignment: BarChartAlignment.spaceAround,
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            topTitles: const AxisTitles(),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index >= trend.length) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      _monthLabel(trend[index].period),
                      style: theme.textTheme.labelSmall,
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
                    color: theme.colorScheme.primary,
                    width: 18,
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

/// A month grid shaded by how much was spent each day. Tapping a day
/// surfaces its transactions via [onDayTap].
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
    final theme = Theme.of(context);
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
                  child: Text(label, style: theme.textTheme.labelSmall),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
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
            final intensity = spent == null || maxDailyMinor == 0
                ? 0.0
                : (spent / maxDailyMinor).clamp(0.15, 1.0);
            final color = spent == null
                ? theme.colorScheme.surfaceContainerHighest
                : Color.lerp(
                    theme.colorScheme.primaryContainer,
                    theme.colorScheme.primary,
                    intensity,
                  );

            return Padding(
              padding: const EdgeInsets.all(2),
              child: InkWell(
                borderRadius: BorderRadius.circular(6),
                onTap: () => onDayTap(DateTime(year, month, dayNumber)),
                child: Container(
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '$dayNumber',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: spent == null
                          ? theme.colorScheme.onSurfaceVariant
                          : theme.colorScheme.onPrimary,
                    ),
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
