import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intellispendiq/core/money.dart';
import 'package:intellispendiq/core/time.dart';
import 'package:intellispendiq/design/design.dart';
import 'package:intellispendiq/domain/models/enums.dart';
import 'package:intellispendiq/domain/models/savings_goal.dart';
import 'package:intellispendiq/domain/models/savings_goal_entry.dart';
import 'package:intellispendiq/savings_goals/cubit/cubit.dart';

/// One goal's progress card in the list: name, saved/target, a bar,
/// and (when a date is set) days remaining.
class SavingsGoalCard extends StatelessWidget {
  const SavingsGoalCard({
    required this.goal,
    required this.savedMinor,
    this.onTap,
    super.key,
  });

  final SavingsGoal goal;
  final int savedMinor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final progress = goal.targetMinor <= 0 ? 0.0 : savedMinor / goal.targetMinor;
    final remaining = goal.targetMinor - savedMinor;

    return Padding(
      padding: const EdgeInsets.only(bottom: Space.cardGap),
      child: AppCard(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    goal.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.rowTitle(color: colors.onSurface),
                  ),
                ),
                MoneyText(savedMinor, size: MoneySize.row),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'of ${Money.display(goal.targetMinor)}',
              style: AppTypography.metadata(color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: Space.x1),
            ProgressMeter(value: progress),
            const SizedBox(height: 6),
            Row(
              children: [
                Text(
                  remaining > 0
                      ? '${Money.display(remaining)} to go'
                      : 'Target reached',
                  style: AppTypography.metadata(color: colors.onSurfaceVariant),
                ),
                if (goal.targetDate != null) ...[
                  const Spacer(),
                  Text(
                    'by ${Iso.formatDateDdMmYyyy(goal.targetDate!)}',
                    style: AppTypography.metadata(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// One movement of money in a goal's history: a contribution, a plain
/// withdrawal, or the goal-funded portion of a purchase.
class SavingsGoalEntryTile extends StatelessWidget {
  const SavingsGoalEntryTile({
    required this.entry,
    required this.accountName,
    super.key,
  });

  final SavingsGoalEntry entry;
  final String accountName;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isContribution = entry.kind == GoalEntryKind.contribution;
    final title = isContribution
        ? 'Contribution from $accountName'
        : (entry.linkedTransactionId != null
              ? 'Spent — released to purchase'
              : 'Withdrawn back to $accountName');

    return Padding(
      padding: const EdgeInsets.only(bottom: Space.cardGap),
      child: AppCard(
        child: Row(
          children: [
            AppIcon(
              isContribution ? AppIcons.moneyIn : AppIcons.moneyOut,
              size: 20,
              color: colors.onSurfaceVariant,
            ),
            const SizedBox(width: Space.x2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTypography.rowTitle(color: colors.onSurface)),
                  if (entry.note != null && entry.note!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      entry.note!,
                      style: AppTypography.metadata(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                  const SizedBox(height: 2),
                  Text(
                    Iso.formatDateDdMmYyyy(entry.transactedAt.toLocal()),
                    style: AppTypography.metadata(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            MoneyText.signed(entry.amountMinor, isInflow: isContribution),
          ],
        ),
      ),
    );
  }
}

/// Creates a new savings goal: name, target amount, optional target
/// date and default account.
class CreateSavingsGoalSheet extends StatefulWidget {
  const CreateSavingsGoalSheet({super.key});

  static Future<void> show(BuildContext context) {
    final cubit = context.read<SavingsGoalsCubit>();
    return AppSheet.show<void>(
      context,
      builder: (_) => BlocProvider.value(
        value: cubit,
        child: const CreateSavingsGoalSheet(),
      ),
    );
  }

  @override
  State<CreateSavingsGoalSheet> createState() => _CreateSavingsGoalSheetState();
}

class _CreateSavingsGoalSheetState extends State<CreateSavingsGoalSheet> {
  final _nameController = TextEditingController();
  final _targetController = TextEditingController();
  DateTime? _targetDate;
  String? _defaultAccountId;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _targetController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _targetDate ?? DateTime.now().add(const Duration(days: 90)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
    );
    if (date == null) return;
    setState(() => _targetDate = date);
  }

  Future<void> _save() async {
    final navigator = Navigator.of(context);
    await context.read<SavingsGoalsCubit>().create(
      name: _nameController.text,
      targetAmount: _targetController.text,
      targetDate: _targetDate,
      defaultAccountId: _defaultAccountId,
    );
    if (!mounted) return;
    final state = context.read<SavingsGoalsCubit>().state;
    if (state.status == SavingsGoalsStatus.invalid) {
      setState(() => _error = state.errorMessage);
      return;
    }
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final accounts = context.watch<SavingsGoalsCubit>().state.accounts;
    final colors = Theme.of(context).colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('New savings goal', style: AppTypography.sectionHeader()),
        const SizedBox(height: Space.x2),
        AppTextField(
          controller: _nameController,
          label: 'What are you saving for?',
          hint: 'New laptop',
          textCapitalization: TextCapitalization.sentences,
          autofocus: true,
        ),
        const SizedBox(height: Space.x2),
        AmountField(
          controller: _targetController,
          label: 'Target amount',
          errorText: _error,
        ),
        const SizedBox(height: Space.x2),
        AppListRow(
          title: const Text('Target date (optional)'),
          subtitle: Text(
            _targetDate == null
                ? 'No date set'
                : Iso.formatDateDdMmYyyy(_targetDate!),
          ),
          trailing: AppIcon(
            AppIcons.chevronRight,
            size: 18,
            color: colors.onSurfaceVariant,
          ),
          onTap: _pickDate,
        ),
        if (accounts.isNotEmpty) ...[
          const SizedBox(height: Space.x2),
          DropdownButtonFormField<String>(
            initialValue: _defaultAccountId,
            decoration: const InputDecoration(
              labelText: 'Contribute from (optional)',
            ),
            items: [
              for (final account in accounts)
                DropdownMenuItem(value: account.id, child: Text(account.name)),
            ],
            onChanged: (value) => setState(() => _defaultAccountId = value),
          ),
        ],
        const SizedBox(height: Space.x3),
        AppButton.primary(label: 'Create goal', onPressed: _save),
      ],
    );
  }
}

/// Earmarks money from a real account toward a goal. Never recorded as
/// an expense — see [SavingsGoal] doc comment.
class ContributeToGoalSheet extends StatefulWidget {
  const ContributeToGoalSheet({super.key});

  static Future<void> show(BuildContext context) {
    final cubit = context.read<SavingsGoalDetailCubit>();
    return AppSheet.show<void>(
      context,
      builder: (_) => BlocProvider.value(
        value: cubit,
        child: const ContributeToGoalSheet(),
      ),
    );
  }

  @override
  State<ContributeToGoalSheet> createState() => _ContributeToGoalSheetState();
}

class _ContributeToGoalSheetState extends State<ContributeToGoalSheet> {
  final _amountController = TextEditingController();
  String? _accountId;
  String? _error;

  @override
  void initState() {
    super.initState();
    final state = context.read<SavingsGoalDetailCubit>().state;
    _accountId = state.goal?.defaultAccountId ??
        (state.accounts.isEmpty ? null : state.accounts.first.id);
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_accountId == null) {
      setState(() => _error = 'Pick an account');
      return;
    }
    final navigator = Navigator.of(context);
    await context.read<SavingsGoalDetailCubit>().contribute(
      accountId: _accountId!,
      amount: _amountController.text,
      transactedAt: DateTime.now(),
    );
    if (!mounted) return;
    final state = context.read<SavingsGoalDetailCubit>().state;
    if (state.status == SavingsGoalDetailStatus.invalid) {
      setState(() => _error = state.errorMessage);
      return;
    }
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final accounts = context.watch<SavingsGoalDetailCubit>().state.accounts;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Add to goal', style: AppTypography.sectionHeader()),
        const SizedBox(height: Space.x1),
        Text(
          'Money moved from an account into this goal — not spend.',
          style: AppTypography.metadata(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: Space.x2),
        DropdownButtonFormField<String>(
          initialValue: _accountId,
          decoration: const InputDecoration(labelText: 'From'),
          items: [
            for (final account in accounts)
              DropdownMenuItem(value: account.id, child: Text(account.name)),
          ],
          onChanged: (value) => setState(() => _accountId = value),
        ),
        const SizedBox(height: Space.x2),
        AmountField(controller: _amountController, errorText: _error),
        const SizedBox(height: Space.x3),
        AppButton.primary(label: 'Add to goal', onPressed: _save),
      ],
    );
  }
}

/// Releases money back out of a goal without spending it.
class WithdrawFromGoalSheet extends StatefulWidget {
  const WithdrawFromGoalSheet({super.key});

  static Future<void> show(BuildContext context) {
    final cubit = context.read<SavingsGoalDetailCubit>();
    return AppSheet.show<void>(
      context,
      builder: (_) => BlocProvider.value(
        value: cubit,
        child: const WithdrawFromGoalSheet(),
      ),
    );
  }

  @override
  State<WithdrawFromGoalSheet> createState() => _WithdrawFromGoalSheetState();
}

class _WithdrawFromGoalSheetState extends State<WithdrawFromGoalSheet> {
  final _amountController = TextEditingController();
  String? _accountId;
  String? _error;

  @override
  void initState() {
    super.initState();
    final state = context.read<SavingsGoalDetailCubit>().state;
    _accountId = state.goal?.defaultAccountId ??
        (state.accounts.isEmpty ? null : state.accounts.first.id);
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_accountId == null) {
      setState(() => _error = 'Pick an account');
      return;
    }
    final navigator = Navigator.of(context);
    await context.read<SavingsGoalDetailCubit>().withdraw(
      accountId: _accountId!,
      amount: _amountController.text,
      transactedAt: DateTime.now(),
    );
    if (!mounted) return;
    final state = context.read<SavingsGoalDetailCubit>().state;
    if (state.status == SavingsGoalDetailStatus.invalid) {
      setState(() => _error = state.errorMessage);
      return;
    }
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<SavingsGoalDetailCubit>().state;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Take money back out', style: AppTypography.sectionHeader()),
        const SizedBox(height: Space.x1),
        Text(
          'Returns money to the account below — up to '
          '${Money.display(state.savedMinor)} saved.',
          style: AppTypography.metadata(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: Space.x2),
        DropdownButtonFormField<String>(
          initialValue: _accountId,
          decoration: const InputDecoration(labelText: 'Back to'),
          items: [
            for (final account in state.accounts)
              DropdownMenuItem(value: account.id, child: Text(account.name)),
          ],
          onChanged: (value) => setState(() => _accountId = value),
        ),
        const SizedBox(height: Space.x2),
        AmountField(controller: _amountController, errorText: _error),
        const SizedBox(height: Space.x3),
        AppButton.secondary(label: 'Take back out', onPressed: _save),
      ],
    );
  }
}

/// Converts (some of) a goal into an actual purchase: records a real
/// expense and releases whatever was saved toward it — see
/// `SavingsGoalRepository.spend`.
class SpendGoalSheet extends StatefulWidget {
  const SpendGoalSheet({super.key});

  static Future<void> show(BuildContext context) {
    final cubit = context.read<SavingsGoalDetailCubit>();
    return AppSheet.show<void>(
      context,
      builder: (_) => BlocProvider.value(
        value: cubit,
        child: const SpendGoalSheet(),
      ),
    );
  }

  @override
  State<SpendGoalSheet> createState() => _SpendGoalSheetState();
}

class _SpendGoalSheetState extends State<SpendGoalSheet> {
  final _amountController = TextEditingController();
  final _merchantController = TextEditingController();
  String? _accountId;
  String? _categoryId;
  String? _error;

  @override
  void initState() {
    super.initState();
    final state = context.read<SavingsGoalDetailCubit>().state;
    _accountId = state.goal?.defaultAccountId ??
        (state.accounts.isEmpty ? null : state.accounts.first.id);
    _amountController.text = (state.savedMinor / 100).toStringAsFixed(2);
  }

  @override
  void dispose() {
    _amountController.dispose();
    _merchantController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_accountId == null) {
      setState(() => _error = 'Pick an account');
      return;
    }
    final navigator = Navigator.of(context);
    await context.read<SavingsGoalDetailCubit>().spend(
      accountId: _accountId!,
      amount: _amountController.text,
      transactedAt: DateTime.now(),
      categoryId: _categoryId,
      merchant: _merchantController.text.trim().isEmpty
          ? null
          : _merchantController.text.trim(),
    );
    if (!mounted) return;
    final state = context.read<SavingsGoalDetailCubit>().state;
    if (state.status == SavingsGoalDetailStatus.invalid) {
      setState(() => _error = state.errorMessage);
      return;
    }
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<SavingsGoalDetailCubit>().state;
    final expenseCategories = state.categories
        .where((c) => c.type == CategoryType.expense)
        .toList();
    final colors = Theme.of(context).colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Buy it', style: AppTypography.sectionHeader()),
        const SizedBox(height: Space.x1),
        Text(
          'Records the real purchase as spend. Whatever was saved toward '
          'this goal covers it first — the rest, if any, comes straight '
          'from the account.',
          style: AppTypography.metadata(color: colors.onSurfaceVariant),
        ),
        const SizedBox(height: Space.x2),
        AppTextField(
          controller: _merchantController,
          label: 'What did you buy? (optional)',
          textCapitalization: TextCapitalization.sentences,
        ),
        const SizedBox(height: Space.x2),
        AmountField(
          controller: _amountController,
          label: 'Amount paid',
          errorText: _error,
        ),
        const SizedBox(height: Space.x2),
        DropdownButtonFormField<String>(
          initialValue: _accountId,
          decoration: const InputDecoration(labelText: 'Paid from'),
          items: [
            for (final account in state.accounts)
              DropdownMenuItem(value: account.id, child: Text(account.name)),
          ],
          onChanged: (value) => setState(() => _accountId = value),
        ),
        if (expenseCategories.isNotEmpty) ...[
          const SizedBox(height: Space.x2),
          DropdownButtonFormField<String>(
            initialValue: _categoryId,
            decoration: const InputDecoration(labelText: 'Category (optional)'),
            items: [
              for (final category in expenseCategories)
                DropdownMenuItem(
                  value: category.id,
                  child: Text(category.name),
                ),
            ],
            onChanged: (value) => setState(() => _categoryId = value),
          ),
        ],
        const SizedBox(height: Space.x3),
        AppButton.primary(label: 'Record purchase', onPressed: _save),
      ],
    );
  }
}

class NoSavingsGoalsYet extends StatelessWidget {
  const NoSavingsGoalsYet({super.key});

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: AppIcons.savingsGoal,
      title: 'No savings goals yet',
      message:
          'Set a target for something you are saving for — a new laptop, '
          'a deposit, a trip — and track how close you are.',
      actionLabel: 'New goal',
      onAction: () => CreateSavingsGoalSheet.show(context),
    );
  }
}
