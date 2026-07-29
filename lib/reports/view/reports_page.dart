import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intellispendiq/core/money.dart';
import 'package:intellispendiq/data/repositories/transaction_repository.dart';
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

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ReportsCubit>();
    final transactions = context.read<TransactionRepository>();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Reports')),
      body: BlocBuilder<ReportsCubit, ReportsState>(
        builder: (context, state) {
          return Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: () => cubit.shiftMonth(-1),
                  ),
                  Text(state.period, style: theme.textTheme.titleMedium),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: () => cubit.shiftMonth(1),
                  ),
                ],
              ),
              Expanded(
                child: state.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32),
                          child: Text(
                            'No confirmed spending recorded for this month.',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                        children: [
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Total spent',
                                    style: theme.textTheme.labelMedium,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    Money.format(state.totalMinor),
                                    style: theme.textTheme.headlineSmall,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          _BreakdownSection(state: state, cubit: cubit),
                          const SizedBox(height: 24),
                          Text(
                            'Last 6 months',
                            style: theme.textTheme.titleSmall,
                          ),
                          const SizedBox(height: 12),
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: MonthTrendChart(trend: state.monthTrend),
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'Daily spend',
                            style: theme.textTheme.titleSmall,
                          ),
                          const SizedBox(height: 12),
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
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

class _BreakdownSection extends StatelessWidget {
  const _BreakdownSection({required this.state, required this.cubit});

  final ReportsState state;
  final ReportsCubit cubit;

  @override
  Widget build(BuildContext context) {
    final byCategory = state.breakdown == ReportsBreakdown.category;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SegmentedButton<ReportsBreakdown>(
              segments: const [
                ButtonSegment(
                  value: ReportsBreakdown.category,
                  label: Text('By category'),
                ),
                ButtonSegment(
                  value: ReportsBreakdown.account,
                  label: Text('By account'),
                ),
              ],
              selected: {state.breakdown},
              onSelectionChanged: (values) =>
                  cubit.breakdownChanged(values.first),
            ),
            const SizedBox(height: 16),
            if (byCategory)
              SpendDonutChart(
                slices: [
                  for (final row in state.rows)
                    DonutSlice(
                      label: row.categoryName,
                      amountMinor: row.spentMinor,
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
                    ),
                ],
              ),
            const SizedBox(height: 8),
            const Divider(),
            const SizedBox(height: 8),
            if (byCategory)
              for (final row in state.rows)
                SpendListRow(
                  label: row.categoryName,
                  amountMinor: row.spentMinor,
                  share: state.shareOf(row),
                  barWidth: state.barWidthOf(row),
                )
            else
              for (final row in state.accountRows)
                SpendListRow(
                  label: row.accountName,
                  amountMinor: row.spentMinor,
                  share: state.accountShareOf(row),
                  barWidth: state.accountBarWidthOf(row),
                ),
          ],
        ),
      ),
    );
  }
}
