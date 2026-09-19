import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intellispendiq/core/money.dart';
import 'package:intellispendiq/core/time.dart';
import 'package:intellispendiq/data/repositories/account_repository.dart';
import 'package:intellispendiq/data/repositories/category_repository.dart';
import 'package:intellispendiq/data/repositories/savings_goal_repository.dart';
import 'package:intellispendiq/design/design.dart';
import 'package:intellispendiq/savings_goals/cubit/cubit.dart';
import 'package:intellispendiq/savings_goals/widgets/widgets.dart';

class SavingsGoalDetailPage extends StatelessWidget {
  const SavingsGoalDetailPage({required this.goalId, super.key});

  final String goalId;

  static Route<void> route({required String goalId}) {
    return MaterialPageRoute<void>(
      builder: (_) => SavingsGoalDetailPage(goalId: goalId),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => SavingsGoalDetailCubit(
        goals: context.read<SavingsGoalRepository>(),
        accounts: context.read<AccountRepository>(),
        categories: context.read<CategoryRepository>(),
        goalId: goalId,
      )..loadUnawaited(),
      child: const SavingsGoalDetailView(),
    );
  }
}

class SavingsGoalDetailView extends StatelessWidget {
  const SavingsGoalDetailView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SavingsGoalDetailCubit, SavingsGoalDetailState>(
      builder: (context, state) {
        if (state.status == SavingsGoalDetailStatus.notFound) {
          return const Scaffold(body: Center(child: Text('Goal not found')));
        }
        final goal = state.goal;
        if (goal == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final colors = Theme.of(context).colorScheme;

        return Scaffold(
          appBar: AppBar(
            title: Text(goal.name),
            actions: [
              IconButton(
                icon: AppIcon(AppIcons.delete, size: 20),
                tooltip: 'Delete goal',
                onPressed: () => _confirmDelete(context),
              ),
              const SizedBox(width: Space.x1),
            ],
          ),
          body: ListView(
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
                      'SAVED',
                      style: AppTypography.chipOverline(
                        color: AppColors.nightText2,
                      ),
                    ),
                    const SizedBox(height: Space.x1),
                    MoneyText(
                      state.savedMinor,
                      size: MoneySize.display,
                      color: AppColors.nightText,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'of ${Money.display(goal.targetMinor)}'
                      '${goal.targetDate == null ? '' : ' · by ${Iso.formatDateDdMmYyyy(goal.targetDate!)}'}',
                      style: AppTypography.metadata(
                        color: AppColors.nightText2,
                      ),
                    ),
                    const SizedBox(height: Space.x2),
                    ProgressMeter(value: state.progress, onDarkSurface: true),
                  ],
                ),
              ),
              const SizedBox(height: Space.x2),
              Row(
                children: [
                  Expanded(
                    child: StatTile(
                      label: 'Remaining',
                      value: MoneyText(state.remainingMinor, size: MoneySize.meta),
                    ),
                  ),
                  const SizedBox(width: Space.x1),
                  Expanded(
                    child: StatTile(
                      label: 'Progress',
                      value: Text(
                        '${(state.progress.clamp(0, 1) * 100).round()}%',
                        style: AppTypography.metaAmount(color: colors.onSurface),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Space.sectionGap),
              Row(
                children: [
                  Expanded(
                    child: AppButton.primary(
                      label: 'Add money',
                      onPressed: () => ContributeToGoalSheet.show(context),
                    ),
                  ),
                  const SizedBox(width: Space.x1),
                  Expanded(
                    child: AppButton.secondary(
                      label: 'Take out',
                      onPressed: state.savedMinor <= 0
                          ? null
                          : () => WithdrawFromGoalSheet.show(context),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Space.x1),
              AppButton.tertiary(
                label: 'Buy it — spend this goal',
                onPressed: () => SpendGoalSheet.show(context),
              ),
              const SizedBox(height: Space.sectionGap),
              Text('History', style: AppTypography.sectionHeader(color: colors.onSurface)),
              const SizedBox(height: Space.x1),
              if (state.entries.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: Space.x2),
                  child: Text(
                    'No contributions yet.',
                    style: AppTypography.body(color: colors.onSurfaceVariant),
                  ),
                )
              else
                for (final entry in state.entries)
                  SavingsGoalEntryTile(
                    entry: entry,
                    accountName:
                        state.accountNames[entry.accountId] ?? 'Account',
                  ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final cubit = context.read<SavingsGoalDetailCubit>();
    final savedMinor = cubit.state.savedMinor;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete this goal?'),
        content: Text(
          savedMinor > 0
              ? '${Money.display(savedMinor)} saved toward this goal will '
                    'be returned to the account(s) it came from.'
              : 'This goal has no money saved toward it yet.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      final navigator = Navigator.of(context);
      await cubit.deleteGoal();
      navigator.pop();
    }
  }
}
