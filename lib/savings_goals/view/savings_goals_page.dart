import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intellispendiq/data/repositories/account_repository.dart';
import 'package:intellispendiq/data/repositories/savings_goal_repository.dart';
import 'package:intellispendiq/design/design.dart';
import 'package:intellispendiq/savings_goals/cubit/cubit.dart';
import 'package:intellispendiq/savings_goals/view/savings_goal_detail_page.dart';
import 'package:intellispendiq/savings_goals/widgets/widgets.dart';

class SavingsGoalsPage extends StatelessWidget {
  const SavingsGoalsPage({super.key});

  static Route<void> route() {
    return MaterialPageRoute<void>(builder: (_) => const SavingsGoalsPage());
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => SavingsGoalsCubit(
        context.read<SavingsGoalRepository>(),
        context.read<AccountRepository>(),
      )..loadUnawaited(),
      child: const SavingsGoalsView(),
    );
  }
}

class SavingsGoalsView extends StatelessWidget {
  const SavingsGoalsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Savings Goals'),
        actions: [
          IconButton(
            icon: AppIcon(AppIcons.add, size: 22),
            tooltip: 'New goal',
            onPressed: () => CreateSavingsGoalSheet.show(context),
          ),
          const SizedBox(width: Space.x1),
        ],
      ),
      body: BlocBuilder<SavingsGoalsCubit, SavingsGoalsState>(
        builder: (context, state) {
          if (state.isEmpty) return const NoSavingsGoalsYet();
          if (state.status == SavingsGoalsStatus.initial ||
              state.status == SavingsGoalsStatus.loading) {
            return const Center(child: CircularProgressIndicator());
          }

          final totalSaved = state.goals.fold<int>(
            0,
            (sum, goal) => sum + state.savedFor(goal.id),
          );

          return ListView(
            padding: const EdgeInsets.fromLTRB(
              Space.gutter,
              Space.x1,
              Space.gutter,
              Space.x4,
            ),
            children: [
              HeroCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TOTAL SAVED',
                      style: AppTypography.chipOverline(
                        color: AppColors.nightText2,
                      ),
                    ),
                    const SizedBox(height: Space.x1),
                    MoneyText(
                      totalSaved,
                      size: MoneySize.display,
                      color: AppColors.nightText,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'across ${state.goals.length} '
                      '${state.goals.length == 1 ? 'goal' : 'goals'}',
                      style: AppTypography.metadata(
                        color: AppColors.nightText2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: Space.sectionGap),
              for (final goal in state.goals)
                SavingsGoalCard(
                  goal: goal,
                  savedMinor: state.savedFor(goal.id),
                  onTap: () => Navigator.of(
                    context,
                  ).push<void>(SavingsGoalDetailPage.route(goalId: goal.id)),
                ),
            ],
          );
        },
      ),
    );
  }
}
