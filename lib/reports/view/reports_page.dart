import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intellispendiq/data/repositories/transaction_repository.dart';
import 'package:intellispendiq/design/design.dart';
import 'package:intellispendiq/reports/cubit/cubit.dart';
import 'package:intellispendiq/reports/widgets/widgets.dart';

class ReportsPage extends StatelessWidget {
  const ReportsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          ReportsCubit(context.read<TransactionRepository>())..load(),
      child: const ReportsView(),
    );
  }
}

class ReportsView extends StatelessWidget {
  const ReportsView({super.key});

  /// Clears the bottom nav bar and the docked FAB.
  static const _bottomInset = 96.0;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ReportsCubit>();
    final transactions = context.read<TransactionRepository>();

    return Scaffold(
      appBar: AppBar(title: const Text('Insights')),
      body: BlocBuilder<ReportsCubit, ReportsState>(
        builder: (context, state) {
          return Column(
            children: [
              PeriodSelector(
                // Was printing the raw `YYYY-MM` key to the screen.
                label: state.periodLabel,
                onPrevious: () => cubit.shiftMonth(-1),
                onNext: () => cubit.shiftMonth(1),
              ),
              Expanded(
                child: state.isEmpty
                    ? const EmptyState(
                        icon: AppIcons.insights,
                        title: 'Nothing to show for this month',
                        message: 'Once spending is captured, the breakdown '
                            'and trends appear here.',
                      )
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(
                          Space.gutter,
                          0,
                          Space.gutter,
                          _bottomInset,
                        ),
                        children: [
                          _BreakdownSection(state: state, cubit: cubit),
                          const SizedBox(height: Space.sectionGap),
                          const SectionHeader(title: 'Last 6 months'),
                          AppCard(
                            child: MonthTrendChart(trend: state.monthTrend),
                          ),
                          const SizedBox(height: Space.sectionGap),
                          SectionHeader(
                            title: 'Day by day',
                            subtitle: 'Tap a day to see what was captured',
                          ),
                          AppCard(
                            child: SpendCalendarHeatmap(
                              period: state.period,
                              dailySpend: state.dailySpend,
                              maxDailyMinor: state.maxDailyMinor,
                              onDayTap: (day) => showDaySpendSheet(
                                context,
                                transactions,
                                day,
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Spend composition for the month.
///
/// The exact-figures list that used to sit under the donut is gone: the
/// donut's own legend already carries every label, share and amount, so
/// the two were printing the same table twice with different bars.
class _BreakdownSection extends StatelessWidget {
  const _BreakdownSection({required this.state, required this.cubit});

  final ReportsState state;
  final ReportsCubit cubit;

  @override
  Widget build(BuildContext context) {
    final byCategory = state.breakdown == ReportsBreakdown.category;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Where it went'),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SegmentedButton<ReportsBreakdown>(
                segments: const [
                  ButtonSegment(
                    value: ReportsBreakdown.category,
                    label: Text('Category'),
                  ),
                  ButtonSegment(
                    value: ReportsBreakdown.account,
                    label: Text('Account'),
                  ),
                ],
                selected: {state.breakdown},
                showSelectedIcon: false,
                onSelectionChanged: (values) =>
                    cubit.breakdownChanged(values.first),
              ),
              const SizedBox(height: Space.x3),
              if (byCategory)
                SpendDonutChart(
                  slices: [
                    for (final row in state.rows)
                      DonutSlice(
                        label: row.categoryName,
                        amountMinor: row.spentMinor,
                        entityId: row.categoryId,
                      ),
                  ],
                )
              else
                SpendDonutChart(
                  slices: [
                    for (final row in state.accountRows)
                      DonutSlice(
                        label: row.accountName,
                        amountMinor: row.spentMinor,
                        entityId: row.accountId,
                      ),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }
}
