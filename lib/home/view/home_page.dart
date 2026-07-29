import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intellispendiq/budgets/budgets.dart';
import 'package:intellispendiq/data/repositories/raw_capture_repository.dart';
import 'package:intellispendiq/data/repositories/transaction_repository.dart';
import 'package:intellispendiq/domain/services/sms_sync_service.dart';
import 'package:intellispendiq/home/cubit/cubit.dart';
import 'package:intellispendiq/reports/reports.dart';
import 'package:intellispendiq/review/review.dart';
import 'package:intellispendiq/transactions/transactions.dart';
import 'package:intellispendiq/voice/voice.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          HomeCubit(
              transactions: context.read<TransactionRepository>(),
              rawCaptures: context.read<RawCaptureRepository>(),
              smsSync: context.read<SmsSyncService>(),
            )
            ..watchPendingCount()
            ..startCaptureUnawaited(),
      child: const HomeView(),
    );
  }
}

class HomeView extends StatelessWidget {
  const HomeView({super.key});

  static const List<Widget> _pages = [
    TransactionsPage(),
    ReviewInboxPage(),
    BudgetsPage(),
    ReportsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<HomeCubit>();

    return BlocBuilder<HomeCubit, HomeState>(
      builder: (context, state) {
        return Scaffold(
          body: IndexedStack(index: state.tabIndex, children: _pages),
          floatingActionButton: state.tabIndex == 0
              ? const QuickAddButtons()
              : null,
          bottomNavigationBar: NavigationBar(
            selectedIndex: state.tabIndex,
            onDestinationSelected: cubit.tabSelected,
            destinations: [
              const NavigationDestination(
                icon: Icon(Icons.receipt_long_outlined),
                selectedIcon: Icon(Icons.receipt_long),
                label: 'Activity',
              ),
              NavigationDestination(
                icon: Badge.count(
                  count: state.pendingCount,
                  isLabelVisible: state.pendingCount > 0,
                  child: const Icon(Icons.inbox_outlined),
                ),
                selectedIcon: Badge.count(
                  count: state.pendingCount,
                  isLabelVisible: state.pendingCount > 0,
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
          ),
        );
      },
    );
  }
}

class QuickAddButtons extends StatelessWidget {
  const QuickAddButtons({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        FloatingActionButton.small(
          heroTag: 'voice',
          tooltip: 'Voice entry',
          onPressed: () => VoiceEntrySheet.show(context),
          child: const Icon(Icons.mic),
        ),
        const SizedBox(height: 12),
        FloatingActionButton(
          heroTag: 'manual',
          tooltip: 'Add transaction',
          onPressed: () =>
              Navigator.of(context).push<void>(TransactionEntryPage.route()),
          child: const Icon(Icons.add),
        ),
      ],
    );
  }
}
