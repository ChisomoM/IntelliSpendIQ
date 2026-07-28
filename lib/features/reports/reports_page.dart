import 'package:flutter/material.dart';
import 'package:intellispendiq/app/app.dart';
import 'package:intellispendiq/core/money.dart';
import 'package:intellispendiq/core/time.dart';
import 'package:intellispendiq/data/repositories/transaction_repository.dart';

/// Monthly spend by category, aggregated in local SQL (plan §11).
/// No LLM narration in Phase 1 — the numbers speak for themselves.
class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  late String _period = Iso.monthKey(DateTime.now());

  void _shiftMonth(int delta) {
    final parts = _period.split('-');
    final shifted = DateTime(int.parse(parts[0]), int.parse(parts[1]) + delta);
    setState(() => _period = Iso.monthKey(shifted));
  }

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Reports')),
      body: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () => _shiftMonth(-1),
              ),
              Text(_period, style: theme.textTheme.titleMedium),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () => _shiftMonth(1),
              ),
            ],
          ),
          Expanded(
            child: StreamBuilder<List<CategorySpend>>(
              stream: services.transactions.watchSpendByCategory(_period),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final rows = snapshot.data!;
                if (rows.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Text(
                        'No confirmed spending recorded for this month.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                final total = rows.fold<int>(
                  0,
                  (sum, row) => sum + row.spentMinor,
                );
                final largest = rows.first.spentMinor;

                return ListView(
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
                              Money.format(total),
                              style: theme.textTheme.headlineSmall,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    for (final row in rows)
                      _CategoryRow(
                        spend: row,
                        share: total == 0 ? 0 : row.spentMinor / total,
                        barWidth: largest == 0 ? 0 : row.spentMinor / largest,
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.spend,
    required this.share,
    required this.barWidth,
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
