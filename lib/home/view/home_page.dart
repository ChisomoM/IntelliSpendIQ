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
import 'package:intellispendiq/home/widgets/widgets.dart';
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

/// The application shell.
///
/// Owns the only [Scaffold] and the only [AppBar] in the tabbed part of
/// the app. Tab pages used to each build their own, which meant four
/// different app bars with four different action sets and a Settings
/// button that existed on exactly one screen. Here the chrome is
/// constant and the tabs are just bodies, so Review, the Assistant and
/// Settings are one tap from anywhere.
///
/// A tab's *own* controls — Activity's search and filters, Reports'
/// month stepper — stay inside its body, next to the thing they act on,
/// rather than being hoisted into a shared bar they would have to
/// negotiate for space in.
class HomeView extends StatelessWidget {
  const HomeView({super.key});

  /// Indexed by [AppSection.tabs], so the tab order has one definition.
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
          final section = AppSection.fromTabIndex(state.tabIndex);

          return Scaffold(
            appBar: AppBar(
              title: Text(section.label),
              actions: [
                // Rendered only when something is actually waiting, so
                // an empty inbox leaves no residue in the chrome — and
                // when it is not empty, it is visible from every tab
                // rather than only from Home.
                if (state.pendingCount > 0)
                  IconButton(
                    tooltip: '${state.pendingCount} need you',
                    onPressed: () => Navigator.of(
                      context,
                    ).push<void>(ReviewInboxPage.route()),
                    icon: Badge.count(
                      count: state.pendingCount,
                      child: const Icon(Icons.inbox_outlined),
                    ),
                  ),
                IconButton(
                  tooltip: 'Assistant',
                  onPressed: () =>
                      Navigator.of(context).push<void>(ChatPage.route()),
                  icon: const Icon(Icons.forum_outlined),
                ),
                IconButton(
                  tooltip: 'Settings',
                  onPressed: () =>
                      Navigator.of(context).push<void>(SettingsPage.route()),
                  icon: const Icon(Icons.settings_outlined),
                ),
              ],
            ),
            body: IndexedStack(index: state.tabIndex, children: _pages),
            floatingActionButton: const CaptureFab(),
            floatingActionButtonLocation:
                FloatingActionButtonLocation.centerDocked,
            bottomNavigationBar: AppBottomBar(
              currentIndex: state.tabIndex,
              onSelected: cubit.tabSelected,
            ),
          );
        },
      ),
    );
  }

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
