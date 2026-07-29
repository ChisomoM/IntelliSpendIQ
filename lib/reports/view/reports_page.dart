import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intellispendiq/core/money.dart';
import 'package:intellispendiq/data/repositories/transaction_repository.dart';
import 'package:intellispendiq/reports/cubit/cubit.dart';

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
                        padding: const EdgeInsets.all(16),
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
                          for (final row in state.rows)
                            CategorySpendRow(
                              spend: row,
                              share: state.shareOf(row),
                              barWidth: state.barWidthOf(row),
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

class CategorySpendRow extends StatelessWidget {
  const CategorySpendRow({
    required this.spend,
    required this.share,
    required this.barWidth,
    super.key,
  });

  final CategorySpend spend;
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
                child: Text(
                  spend.categoryName,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
              Text(
                Money.format(spend.spentMinor),
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
