import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intellispendiq/app/app.dart';
import 'package:intellispendiq/features/budgets/budgets_page.dart';
import 'package:intellispendiq/features/reports/reports_page.dart';
import 'package:intellispendiq/features/review/review_inbox_page.dart';
import 'package:intellispendiq/features/transactions/transaction_entry_page.dart';
import 'package:intellispendiq/features/transactions/transactions_page.dart';
import 'package:intellispendiq/features/voice/voice_entry_sheet.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _index = 0;
  bool _syncStarted = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_syncStarted) return;
    _syncStarted = true;
    unawaited(_startCapture());
  }

  Future<void> _startCapture() async {
    final services = AppScope.of(context);
    // Live events first so nothing that arrives during the backfill is
    // missed; ingest is idempotent, so any overlap is harmless.
    services.smsSync.startListening();
    try {
      await services.smsSync.backfill();
    } on Object catch (_) {
      // Backfill failure (permission denied, OEM quirk) must not block
      // the app — manual and voice entry still work, and the next
      // launch retries from the stored watermark.
    }
  }

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
    const pages = [
      TransactionsPage(),
      ReviewInboxPage(),
      BudgetsPage(),
      ReportsPage(),
    ];

    return Scaffold(
      body: pages[_index],
      floatingActionButton: _index == 0
          ? _QuickAddButtons(
              onManual: () => Navigator.of(context).push<void>(
                MaterialPageRoute(builder: (_) => const TransactionEntryPage()),
              ),
              onVoice: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                builder: (_) => const VoiceEntrySheet(),
              ),
            )
          : null,
      bottomNavigationBar: StreamBuilder<int>(
        stream: services.transactions.watchReviewCount(),
        builder: (context, txSnapshot) {
          return StreamBuilder<int>(
            stream: services.rawCaptures.watchFailedCount(),
            builder: (context, rawSnapshot) {
              final pending = (txSnapshot.data ?? 0) + (rawSnapshot.data ?? 0);
              return NavigationBar(
                selectedIndex: _index,
                onDestinationSelected: (value) =>
                    setState(() => _index = value),
                destinations: [
                  const NavigationDestination(
                    icon: Icon(Icons.receipt_long_outlined),
                    selectedIcon: Icon(Icons.receipt_long),
                    label: 'Activity',
                  ),
                  NavigationDestination(
                    icon: Badge.count(
                      count: pending,
                      isLabelVisible: pending > 0,
                      child: const Icon(Icons.inbox_outlined),
                    ),
                    selectedIcon: Badge.count(
                      count: pending,
                      isLabelVisible: pending > 0,
                      child: const Icon(Icons.inbox),
                    ),
                    label: 'Review',
                  ),
                  const NavigationDestination(
                    icon: Icon(Icons.savings_outlined),
                    selectedIcon: Icon(Icons.savings),
                    label: 'Budgets',
                  ),
                  const NavigationDestination(
                    icon: Icon(Icons.pie_chart_outline),
                    selectedIcon: Icon(Icons.pie_chart),
                    label: 'Reports',
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _QuickAddButtons extends StatelessWidget {
  const _QuickAddButtons({required this.onManual, required this.onVoice});

  final VoidCallback onManual;
  final VoidCallback onVoice;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        FloatingActionButton.small(
          heroTag: 'voice',
          onPressed: onVoice,
          tooltip: 'Voice entry',
          child: const Icon(Icons.mic),
        ),
        const SizedBox(height: 12),
        FloatingActionButton(
          heroTag: 'manual',
          onPressed: onManual,
          tooltip: 'Add transaction',
          child: const Icon(Icons.add),
        ),
      ],
    );
  }
}
