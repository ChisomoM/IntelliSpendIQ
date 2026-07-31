import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intellispendiq/core/app_section.dart';
import 'package:intellispendiq/dashboard/cubit/cubit.dart';
import 'package:intellispendiq/dashboard/widgets/widgets.dart';
import 'package:intellispendiq/data/repositories/category_repository.dart';
import 'package:intellispendiq/data/repositories/raw_capture_repository.dart';
import 'package:intellispendiq/data/repositories/transaction_repository.dart';
import 'package:intellispendiq/home/cubit/cubit.dart';
import 'package:intellispendiq/review/review.dart';
import 'package:intellispendiq/ui/ui.dart';
import 'package:intellispendiq/voice/voice.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => DashboardCubit(
        transactions: context.read<TransactionRepository>(),
        categories: context.read<CategoryRepository>(),
        rawCaptures: context.read<RawCaptureRepository>(),
      )..loadUnawaited(),
      child: const DashboardView(),
    );
  }
}

class DashboardView extends StatelessWidget {
  const DashboardView({super.key});

  @override
  Widget build(BuildContext context) {
    // No Scaffold and no AppBar: the shell owns both, so this is a body.
    return BlocBuilder<DashboardCubit, DashboardState>(
      builder: (context, state) {
        if (state.status == DashboardStatus.initial) {
          return const LoadingState(showHeader: true);
        }

        final home = context.read<HomeCubit>();

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          children: [
            GreetingHeader(period: state.period),
            const SizedBox(height: 16),
            ReviewBanner(
              count: state.pendingReviewCount,
              onTap: () =>
                  Navigator.of(context).push<void>(ReviewInboxPage.route()),
            ),
            if (state.pendingReviewCount > 0) const SizedBox(height: 12),
            // Typing an entry is the FAB and the Assistant is in the app
            // bar, so the old three-up quick-action row would now be
            // repeating the chrome. Only voice is left, because it has
            // no other home on this screen.
            VoiceCaptureButton(
              onPressed: () => VoiceEntrySheet.show(context),
            ),
            const SizedBox(height: 12),
            IncomeOverviewCard(
              hasIncome: state.hasIncome,
              incomeMinor: state.totalIncomeMinor,
              totalSpent: state.totalSpent,
              onTap: () => home.tabSelected(AppSection.budgets.tabIndex),
            ),
            const SizedBox(height: 12),
            TopCategoriesCard(
              categories: state.topCategories,
              onSeeAll: () => home.tabSelected(AppSection.reports.tabIndex),
            ),
            if (state.topCategories.isNotEmpty) const SizedBox(height: 12),
            RecentActivityCard(
              transactions: state.recentTransactions,
              onSeeAll: () => home.tabSelected(AppSection.activity.tabIndex),
            ),
          ],
        );
      },
    );
  }
}
