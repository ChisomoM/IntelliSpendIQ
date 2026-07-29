import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intellispendiq/app/cubit/cubit.dart';
import 'package:intellispendiq/budgets/budgets.dart';
import 'package:intellispendiq/chat/chat.dart';
import 'package:intellispendiq/core/app_section.dart';
import 'package:intellispendiq/core/deep_link.dart';
import 'package:intellispendiq/dashboard/dashboard.dart';
import 'package:intellispendiq/data/repositories/raw_capture_repository.dart';
import 'package:intellispendiq/data/repositories/transaction_repository.dart';
import 'package:intellispendiq/domain/services/sms_sync_service.dart';
import 'package:intellispendiq/home/cubit/cubit.dart';
import 'package:intellispendiq/reports/reports.dart';
import 'package:intellispendiq/review/review.dart';
import 'package:intellispendiq/settings/settings.dart';
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

  /// Indexed by [AppSection.tabs], so the tab order has one definition.
  /// Review, Assistant, and Settings are reached by push instead of a
  /// nav slot — see [_openLink].
  static const List<Widget> _pages = [
    DashboardPage(),
    TransactionsPage(),
    BudgetsPage(),
    ReportsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<HomeCubit>();

    // Deep links are dispatched here rather than at the app root
    // because this is the first widget that exists only when the app is
    // unlocked. A link that arrives at the lock screen just waits in
    // DeepLinkCubit until this mounts.
    return BlocListener<DeepLinkCubit, DeepLinkState>(
      listenWhen: (previous, current) => current.hasPending,
      listener: (context, state) => _openLink(context, state.pending!),
      child: BlocBuilder<HomeCubit, HomeState>(
        builder: (context, state) {
          return Scaffold(
            body: IndexedStack(index: state.tabIndex, children: _pages),
            floatingActionButton: state.tabIndex == AppSection.activity.tabIndex
                ? const QuickAddButtons()
                : null,
            bottomNavigationBar: NavigationBar(
              selectedIndex: state.tabIndex,
              onDestinationSelected: cubit.tabSelected,
              destinations: [
                for (final section in AppSection.tabs)
                  _destinationFor(section, state),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Only ever called with an [AppSection.tabs] member — Review,
  /// Assistant, and Settings have no nav slot to build here.
  NavigationDestination _destinationFor(AppSection section, HomeState state) {
    return switch (section) {
      AppSection.home => NavigationDestination(
        icon: _reviewBadge(state, const Icon(Icons.dashboard_outlined)),
        selectedIcon: _reviewBadge(state, const Icon(Icons.dashboard)),
        label: 'Home',
      ),
      AppSection.activity => const NavigationDestination(
        icon: Icon(Icons.receipt_long_outlined),
        selectedIcon: Icon(Icons.receipt_long),
        label: 'Activity',
      ),
      AppSection.budgets => const NavigationDestination(
        icon: Icon(Icons.savings_outlined),
        selectedIcon: Icon(Icons.savings),
        label: 'Budgets',
      ),
      AppSection.reports => const NavigationDestination(
        icon: Icon(Icons.pie_chart_outline),
        selectedIcon: Icon(Icons.pie_chart),
        label: 'Reports',
      ),
      AppSection.review || AppSection.chat || AppSection.settings =>
        throw UnimplementedError('${section.name} is not a nav tab'),
    };
  }

  Widget _reviewBadge(HomeState state, Icon icon) => Badge.count(
    count: state.pendingCount,
    isLabelVisible: state.pendingCount > 0,
    child: icon,
  );

  Future<void> _openLink(BuildContext context, DeepLink link) async {
    final home = context.read<HomeCubit>();
    final deepLinks = context.read<DeepLinkCubit>();
    final transactions = context.read<TransactionRepository>();

    // Claim it before navigating, so a slow lookup cannot let the same
    // link fire twice.
    deepLinks.consumed();

    switch (link) {
      case SectionLink(:final section) when section.isTab:
        home.tabSelected(section.tabIndex);
      case SectionLink(section: AppSection.review):
        await Navigator.of(context).push<void>(ReviewInboxPage.route());
      case SectionLink(section: AppSection.chat):
        await Navigator.of(context).push<void>(ChatPage.route());
      case SectionLink(section: AppSection.settings):
        await Navigator.of(context).push<void>(SettingsPage.route());
      case SectionLink():
        break;
      case AddTransactionLink():
        await Navigator.of(context).push<void>(TransactionEntryPage.route());
      case VoiceEntryLink():
        await VoiceEntrySheet.show(context);
      case TransactionLink(:final id):
        final existing = await transactions.byId(id);
        // A link to a deleted or unknown transaction lands on the
        // activity list rather than an empty form.
        if (!context.mounted) return;
        if (existing == null) {
          home.tabSelected(AppSection.home.tabIndex);
          return;
        }
        await Navigator.of(
          context,
        ).push<void>(TransactionEntryPage.route(existing: existing));
    }
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
