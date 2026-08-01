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
import 'package:intellispendiq/design/design.dart';
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

  /// The Review badge used to sit on this tab's icon, pointing at a
  /// destination that was not the inbox — Home shows a review count,
  /// Review itself is a push. It now lives as an entry point on the
  /// Home screen's own content instead (`ReviewBanner`), so nothing
  /// here needs the pending count.
  static const List<AppNavDestination> _destinations = [
    AppNavDestination(
      icon: AppIcons.home,
      selectedIcon: AppIcons.home,
      label: 'Home',
    ),
    AppNavDestination(
      icon: AppIcons.activity,
      selectedIcon: AppIcons.activity,
      label: 'Activity',
    ),
    AppNavDestination(
      icon: AppIcons.budgets,
      selectedIcon: AppIcons.budgets,
      label: 'Budgets',
    ),
    // Still `AppSection.reports` underneath — the Insights merge with
    // the Assistant (redesign plan Phase 8) is a content change, not a
    // navigation one, so the section/route stays `reports` and only
    // the label moves ahead of it.
    AppNavDestination(
      icon: AppIcons.insights,
      selectedIcon: AppIcons.insights,
      label: 'Insights',
    ),
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
            floatingActionButton: CenterFab(
              onTap: () => Navigator.of(
                context,
              ).push<void>(TransactionEntryPage.route()),
              onDoubleTap: () => VoiceEntrySheet.show(context),
              onLongPress: () => _showQuickAddSheet(context),
            ),
            floatingActionButtonLocation:
                FloatingActionButtonLocation.centerDocked,
            bottomNavigationBar: AppNavBar(
              destinations: _destinations,
              selectedIndex: state.tabIndex,
              onDestinationSelected: cubit.tabSelected,
            ),
          );
        },
      ),
    );
  }

  Future<void> _showQuickAddSheet(BuildContext context) {
    return AppSheet.show<void>(
      context,
      isScrollControlled: false,
      builder: (sheetContext) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppListRow(
            leading: AppIcon(AppIcons.add),
            title: const Text('Add transaction'),
            onTap: () {
              Navigator.of(sheetContext).pop();
              Navigator.of(
                context,
              ).push<void>(TransactionEntryPage.route());
            },
          ),
          AppListRow(
            leading: AppIcon(AppIcons.voice),
            title: const Text('Voice entry'),
            onTap: () {
              Navigator.of(sheetContext).pop();
              VoiceEntrySheet.show(context);
            },
          ),
          const SizedBox(height: Space.x1),
        ],
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
