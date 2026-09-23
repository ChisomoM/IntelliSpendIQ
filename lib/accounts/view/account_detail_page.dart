import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intellispendiq/accounts/cubit/cubit.dart';
import 'package:intellispendiq/accounts/widgets/widgets.dart';
import 'package:intellispendiq/data/repositories/account_repository.dart';
import 'package:intellispendiq/data/repositories/category_repository.dart';
import 'package:intellispendiq/data/repositories/transaction_repository.dart';
import 'package:intellispendiq/data/repositories/transfer_repository.dart';
import 'package:intellispendiq/design/design.dart';
import 'package:intellispendiq/domain/models/account.dart';
import 'package:intellispendiq/domain/models/category.dart';
import 'package:intellispendiq/domain/models/transaction.dart';
import 'package:intellispendiq/domain/models/transfer.dart';
import 'package:intellispendiq/transactions/cubit/activity_entry.dart';
import 'package:intellispendiq/transactions/view/transaction_entry_page.dart';
import 'package:intellispendiq/transactions/widgets/widgets.dart';
import 'package:intl/intl.dart';

/// One account's ledger: live balance, money in/out, and every
/// transaction or transfer posted against it.
class AccountDetailPage extends StatelessWidget {
  const AccountDetailPage({required this.accountId, super.key});

  final String accountId;

  static Route<void> route({required String accountId}) {
    return MaterialPageRoute<void>(
      builder: (_) => AccountDetailPage(accountId: accountId),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (context) => AccountDetailCubit(
            accounts: context.read<AccountRepository>(),
            transactions: context.read<TransactionRepository>(),
            transfers: context.read<TransferRepository>(),
            categories: context.read<CategoryRepository>(),
            accountId: accountId,
          )..loadUnawaited(),
        ),
        // The overflow actions (edit balance, set default, delete)
        // reuse the sheets already wired to [AccountsCubit].
        BlocProvider(
          create: (context) => AccountsCubit(
            context.read<AccountRepository>(),
            context.read<TransferRepository>(),
          )..loadUnawaited(),
        ),
      ],
      child: const AccountDetailView(),
    );
  }
}

class AccountDetailView extends StatelessWidget {
  const AccountDetailView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AccountDetailCubit, AccountDetailState>(
      builder: (context, state) {
        if (state.status == AccountDetailStatus.initial ||
            state.status == AccountDetailStatus.loading) {
          return Scaffold(
            appBar: AppBar(),
            body: const Padding(
              padding: EdgeInsets.all(Space.gutter),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LoadingSkeleton(width: double.infinity, height: 72),
                  SizedBox(height: Space.sectionGap),
                  LoadingSkeleton(width: double.infinity, height: 148),
                ],
              ),
            ),
          );
        }
        if (state.status == AccountDetailStatus.notFound ||
            state.account == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const ErrorState(
              message: 'This account no longer exists.',
            ),
          );
        }

        final account = state.account!;
        final colors = Theme.of(context).colorScheme;

        return Scaffold(
          appBar: AppBar(
            title: Text(
              account.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            actions: [
              IconButton(
                icon: const AppIcon(AppIcons.add, size: 22),
                tooltip: 'Add an entry',
                onPressed: () => _addEntry(context, account.id),
              ),
              PopupMenuButton<_AccountDetailAction>(
                icon: AppIcon(
                  AppIcons.more,
                  size: 20,
                  color: colors.onSurfaceVariant,
                ),
                onSelected: (action) => _handle(context, account, action),
                itemBuilder: (context) => [
                  if (!account.isDefault)
                    const PopupMenuItem(
                      value: _AccountDetailAction.setDefault,
                      child: Text('Set as default'),
                    ),
                  const PopupMenuItem(
                    value: _AccountDetailAction.editBalance,
                    child: Text('Edit balance'),
                  ),
                  const PopupMenuItem(
                    value: _AccountDetailAction.delete,
                    child: Text('Delete'),
                  ),
                ],
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.only(top: Space.x1, bottom: Space.x4),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
                child: HeroCard(
                  onTap: () => BalanceEditorSheet.show(
                    context,
                    account: account,
                    currentBalanceMinor: state.balanceMinor,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        accountTypeLabel(account.type).toUpperCase(),
                        style: AppTypography.chipOverline(
                          color: AppColors.nightText2,
                        ),
                      ),
                      const SizedBox(height: Space.x1),
                      MoneyText(
                        state.balanceMinor,
                        size: MoneySize.display,
                        color: AppColors.nightText,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: Space.sectionGap),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
                child: AccountStatTiles(
                  moneyInMinor: state.moneyInMinor,
                  moneyOutMinor: state.moneyOutMinor,
                ),
              ),
              const SizedBox(height: Space.sectionGap),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: Space.gutter),
                child: SectionHeader(title: 'Activity'),
              ),
              if (state.isEmpty)
                EmptyState(
                  icon: AppIcons.emptyActivity,
                  title: 'Nothing on this account yet',
                  message:
                      'Entries recorded against ${account.name} will show '
                      'up here.',
                  actionLabel: 'Add an entry',
                  onAction: () => _addEntry(context, account.id),
                )
              else
                for (final group in state.dayGroups) ...[
                  _DayHeader(group: group),
                  for (final entry in group.entries)
                    _entryRow(
                      context,
                      entry,
                      accountId: account.id,
                      categoriesById: state.categoriesById,
                      accountNames: state.accountNames,
                    ),
                ],
            ],
          ),
        );
      },
    );
  }

  Widget _entryRow(
    BuildContext context,
    ActivityEntry entry, {
    required String accountId,
    required Map<String, Category> categoriesById,
    required Map<String, String> accountNames,
  }) {
    return switch (entry) {
      TransactionEntry(:final transaction) => Dismissible(
        key: ValueKey(transaction.id),
        direction: DismissDirection.endToStart,
        background: _dismissBackground(context),
        onDismissed: (_) => _deleteTransaction(context, transaction),
        child: TransactionTile(
          transaction: transaction,
          category: categoriesById[transaction.categoryId],
        ),
      ),
      TransferEntry(:final transfer) => Dismissible(
        key: ValueKey(transfer.id),
        direction: DismissDirection.endToStart,
        background: _dismissBackground(context),
        onDismissed: (_) => _deleteTransfer(context, transfer),
        child: TransferTile(
          transfer: transfer,
          fromAccountName: accountNames[transfer.fromAccountId] ?? 'Unknown',
          toAccountName: accountNames[transfer.toAccountId] ?? 'Unknown',
          perspectiveAccountId: accountId,
        ),
      ),
    };
  }

  Widget _dismissBackground(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.errorContainer,
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.symmetric(horizontal: Space.x3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          AppIcon(
            AppIcons.delete,
            size: 20,
            color: Theme.of(context).colorScheme.onErrorContainer,
          ),
          const SizedBox(width: Space.x1),
          Text(
            'Delete',
            style: AppTypography.rowTitle(
              color: Theme.of(context).colorScheme.onErrorContainer,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteTransaction(
    BuildContext context,
    Transaction transaction,
  ) async {
    final cubit = context.read<AccountDetailCubit>();
    await cubit.deleteTransaction(transaction.id);
    if (!context.mounted) return;
    showUndoSnackBar(
      context,
      message: transaction.merchant?.isNotEmpty ?? false
          ? 'Deleted "${transaction.merchant}"'
          : 'Entry deleted',
      onUndo: () => cubit.undeleteTransaction(transaction.id),
    );
  }

  Future<void> _deleteTransfer(
    BuildContext context,
    Transfer transfer,
  ) async {
    final cubit = context.read<AccountDetailCubit>();
    await cubit.deleteTransfer(transfer.id);
    if (!context.mounted) return;
    showUndoSnackBar(
      context,
      message: 'Transfer deleted',
      onUndo: () => cubit.undeleteTransfer(transfer.id),
    );
  }

  void _addEntry(BuildContext context, String accountId) {
    Navigator.of(context).push<void>(
      TransactionEntryPage.route(initialAccountId: accountId),
    );
  }

  void _handle(
    BuildContext context,
    Account account,
    _AccountDetailAction action,
  ) {
    final accountsCubit = context.read<AccountsCubit>();
    final detail = context.read<AccountDetailCubit>().state;
    switch (action) {
      case _AccountDetailAction.setDefault:
        accountsCubit.setDefault(account.id);
      case _AccountDetailAction.editBalance:
        BalanceEditorSheet.show(
          context,
          account: account,
          currentBalanceMinor: detail.balanceMinor,
        );
      case _AccountDetailAction.delete:
        _confirmDelete(context, account);
    }
  }

  Future<void> _confirmDelete(BuildContext context, Account account) async {
    final cubit = context.read<AccountsCubit>();
    final navigator = Navigator.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete this account?'),
        content: Text(
          'Transactions already recorded against "${account.name}" are '
          'kept, but you will not be able to pick it for new ones.',
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
      await cubit.delete(account.id);
      if (!context.mounted) return;
      if (cubit.state.status == AccountsStatus.invalid) return;
      navigator.pop();
    }
  }
}

enum _AccountDetailAction { setDefault, editBalance, delete }

/// Day label on the left, the day's net movement on this account on
/// the right — including transfers, which the global Activity feed
/// leaves out of its net because they don't change household wealth.
class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.group});

  final ActivityDayGroup group;

  static final _dayFormat = DateFormat('EEEE, d MMM');
  static final _dayWithYearFormat = DateFormat('d MMM yyyy');

  String get _label {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final difference = today.difference(group.day).inDays;
    if (difference == 0) return 'Today';
    if (difference == 1) return 'Yesterday';
    if (group.day.year != now.year) {
      return _dayWithYearFormat.format(group.day);
    }
    return _dayFormat.format(group.day);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Space.gutter,
        Space.x2,
        Space.gutter,
        Space.x1,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _label,
              style: AppTypography.metadata(
                color: colors.onSurfaceVariant,
              ).copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          if (group.netMinor != 0)
            MoneyText.signed(
              group.netMinor.abs(),
              isInflow: group.netMinor > 0,
              size: MoneySize.meta,
            ),
        ],
      ),
    );
  }
}
