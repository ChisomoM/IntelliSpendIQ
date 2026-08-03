import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intellispendiq/accounts/cubit/cubit.dart';
import 'package:intellispendiq/design/design.dart';
import 'package:intellispendiq/domain/models/account.dart';
import 'package:intellispendiq/domain/models/enums.dart';

String accountTypeLabel(AccountType type) => switch (type) {
  AccountType.cash => 'Cash',
  AccountType.bank => 'Bank',
  AccountType.mobileMoney => 'Mobile Money',
  AccountType.card => 'Card',
};

List<List<dynamic>> accountTypeIcon(AccountType type) => switch (type) {
  AccountType.cash => AppIcons.accountCash,
  AccountType.bank => AppIcons.accountBank,
  AccountType.mobileMoney => AppIcons.accountMobileMoney,
  AccountType.card => AppIcons.accountCard,
};

/// An account's glyph on its own tinted chip — hue keyed to the
/// account's id, same mechanism [CategoryAvatar] uses for categories, so
/// a column of accounts catches light the same way a column of
/// categories does instead of every account wearing the same violet.
class _AccountAvatar extends StatelessWidget {
  const _AccountAvatar({required this.account});

  final Account account;

  @override
  Widget build(BuildContext context) {
    final hue = CategoryPalette.forCategory(
      categoryId: account.id,
      brightness: Theme.of(context).brightness,
    );

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.alphaBlend(hue.ink.withValues(alpha: 0.06), hue.tint),
            hue.tint,
          ],
        ),
        borderRadius: BorderRadius.circular(44 * 0.3),
      ),
      alignment: Alignment.center,
      child: AppIcon(accountTypeIcon(account.type), size: 20, color: hue.ink),
    );
  }
}

class AccountTile extends StatelessWidget {
  const AccountTile({
    required this.account,
    required this.balanceMinor,
    super.key,
  });

  final Account account;

  /// The account's live computed balance — see
  /// `AccountRepository.watchComputedBalances`.
  final int balanceMinor;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: Space.cardGap),
      child: AppCard(
        child: Row(
          children: [
            _AccountAvatar(account: account),
            const SizedBox(width: Space.x2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          account.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.rowTitle(
                            color: colors.onSurface,
                          ),
                        ),
                      ),
                      if (account.isDefault) ...[
                        const SizedBox(width: 6),
                        AppIcon(AppIcons.check, size: 14, color: colors.primary),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    accountTypeLabel(account.type),
                    style: AppTypography.metadata(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            MoneyText(balanceMinor, size: MoneySize.row),
            PopupMenuButton<_AccountAction>(
              icon: AppIcon(
                AppIcons.more,
                size: 20,
                color: colors.onSurfaceVariant,
              ),
              onSelected: (action) => _handle(context, action),
              itemBuilder: (context) => [
                if (!account.isDefault)
                  const PopupMenuItem(
                    value: _AccountAction.setDefault,
                    child: Text('Set as default'),
                  ),
                const PopupMenuItem(
                  value: _AccountAction.editBalance,
                  child: Text('Edit balance'),
                ),
                const PopupMenuItem(
                  value: _AccountAction.delete,
                  child: Text('Delete'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _handle(BuildContext context, _AccountAction action) {
    switch (action) {
      case _AccountAction.setDefault:
        context.read<AccountsCubit>().setDefault(account.id);
      case _AccountAction.editBalance:
        BalanceEditorSheet.show(
          context,
          account: account,
          currentBalanceMinor: balanceMinor,
        );
      case _AccountAction.delete:
        _confirmDelete(context);
    }
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final cubit = context.read<AccountsCubit>();
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
    if (confirmed ?? false) await cubit.delete(account.id);
  }
}

enum _AccountAction { setDefault, editBalance, delete }

/// Adds a new account. There is deliberately no edit path here — a
/// mistaken account is deleted and re-added rather than renamed.
class AccountEditorSheet extends StatefulWidget {
  const AccountEditorSheet({super.key});

  static Future<void> show(BuildContext context) {
    final cubit = context.read<AccountsCubit>();
    return AppSheet.show<void>(
      context,
      builder: (_) => BlocProvider.value(
        value: cubit,
        child: const AccountEditorSheet(),
      ),
    );
  }

  @override
  State<AccountEditorSheet> createState() => _AccountEditorSheetState();
}

class _AccountEditorSheetState extends State<AccountEditorSheet> {
  final _nameController = TextEditingController();
  final _openingBalanceController = TextEditingController();
  AccountType _type = AccountType.mobileMoney;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _openingBalanceController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final navigator = Navigator.of(context);
    await context.read<AccountsCubit>().add(
      name: _nameController.text,
      type: _type,
      openingBalance: _openingBalanceController.text,
    );
    if (!mounted) return;
    final state = context.read<AccountsCubit>().state;
    if (state.status == AccountsStatus.invalid) {
      setState(() => _error = state.errorMessage);
      return;
    }
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Add account', style: AppTypography.sectionHeader()),
        const SizedBox(height: Space.x2),
        AppTextField(
          controller: _nameController,
          label: 'Account name',
          errorText: _error,
          textCapitalization: TextCapitalization.words,
          autofocus: true,
        ),
        const SizedBox(height: Space.x2),
        DropdownButtonFormField<AccountType>(
          initialValue: _type,
          decoration: const InputDecoration(labelText: 'Type'),
          items: [
            for (final type in AccountType.values)
              DropdownMenuItem(value: type, child: Text(accountTypeLabel(type))),
          ],
          onChanged: (value) => setState(() => _type = value ?? _type),
        ),
        const SizedBox(height: Space.x2),
        AppTextField(
          controller: _openingBalanceController,
          label: 'Opening balance (optional)',
          hint:
              'What it holds right now — leave blank to start from zero and '
              'log transactions as they happen',
          prefixIcon: const Padding(
            padding: EdgeInsets.only(left: 16),
            child: Text('K'),
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp('[0-9.,]')),
          ],
        ),
        const SizedBox(height: Space.x3),
        AppButton.primary(label: 'Add account', onPressed: _save),
      ],
    );
  }
}

/// Sets a new balance checkpoint by hand. Everything logged after this
/// point — SMS, manual, voice, transfers alike — adds on top of
/// whatever figure is entered here; nothing resets it automatically.
class BalanceEditorSheet extends StatefulWidget {
  const BalanceEditorSheet({
    required this.account,
    required this.currentBalanceMinor,
    super.key,
  });

  final Account account;
  final int currentBalanceMinor;

  static Future<void> show(
    BuildContext context, {
    required Account account,
    required int currentBalanceMinor,
  }) {
    final cubit = context.read<AccountsCubit>();
    return AppSheet.show<void>(
      context,
      builder: (_) => BlocProvider.value(
        value: cubit,
        child: BalanceEditorSheet(
          account: account,
          currentBalanceMinor: currentBalanceMinor,
        ),
      ),
    );
  }

  @override
  State<BalanceEditorSheet> createState() => _BalanceEditorSheetState();
}

class _BalanceEditorSheetState extends State<BalanceEditorSheet> {
  late final TextEditingController _amountController = TextEditingController(
    text: (widget.currentBalanceMinor / 100).toStringAsFixed(2),
  );
  String? _error;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final navigator = Navigator.of(context);
    await context.read<AccountsCubit>().updateBalance(
      widget.account.id,
      _amountController.text,
    );
    if (!mounted) return;
    final state = context.read<AccountsCubit>().state;
    if (state.status == AccountsStatus.invalid) {
      setState(() => _error = state.errorMessage);
      return;
    }
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Edit balance for ${widget.account.name}',
          style: AppTypography.sectionHeader(),
        ),
        const SizedBox(height: Space.x2),
        AmountField(
          controller: _amountController,
          errorText: _error,
          autofocus: true,
        ),
        const SizedBox(height: Space.x3),
        AppButton.primary(label: 'Save', onPressed: _save),
      ],
    );
  }
}

/// Records money moved between two of the user's own accounts by
/// hand — the manual counterpart to the transfer suggestions the
/// Review Inbox detects automatically. Needed for moves that never
/// produce a matching pair of transactions on their own, like an ATM
/// cash withdrawal: the bank sends a debit SMS, but the cash account
/// has no way to send a message announcing its side of it.
class RecordTransferSheet extends StatefulWidget {
  const RecordTransferSheet({super.key});

  static Future<void> show(BuildContext context) {
    final cubit = context.read<AccountsCubit>();
    return AppSheet.show<void>(
      context,
      builder: (_) => BlocProvider.value(
        value: cubit,
        child: const RecordTransferSheet(),
      ),
    );
  }

  @override
  State<RecordTransferSheet> createState() => _RecordTransferSheetState();
}

class _RecordTransferSheetState extends State<RecordTransferSheet> {
  final _amountController = TextEditingController();
  final _feeController = TextEditingController();
  String? _fromAccountId;
  String? _toAccountId;
  DateTime _transactedAt = DateTime.now();
  String? _error;

  @override
  void dispose() {
    _amountController.dispose();
    _feeController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _transactedAt,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_transactedAt),
    );
    if (!mounted) return;
    setState(() {
      _transactedAt = DateTime(
        date.year,
        date.month,
        date.day,
        time?.hour ?? _transactedAt.hour,
        time?.minute ?? _transactedAt.minute,
      );
    });
  }

  Future<void> _save() async {
    if (_fromAccountId == null || _toAccountId == null) {
      setState(() => _error = 'Pick both accounts');
      return;
    }
    final navigator = Navigator.of(context);
    await context.read<AccountsCubit>().recordTransfer(
      fromAccountId: _fromAccountId!,
      toAccountId: _toAccountId!,
      amount: _amountController.text,
      transactedAt: _transactedAt,
      fee: _feeController.text,
    );
    if (!mounted) return;
    final state = context.read<AccountsCubit>().state;
    if (state.status == AccountsStatus.invalid) {
      setState(() => _error = state.errorMessage);
      return;
    }
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final accounts = context.watch<AccountsCubit>().state.accounts;
    final colors = Theme.of(context).colorScheme;

    if (accounts.length < 2) {
      return Padding(
        padding: const EdgeInsets.all(Space.x3),
        child: Text(
          'Add a second account before recording a transfer between them.',
          style: AppTypography.body(color: colors.onSurfaceVariant),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Record a transfer', style: AppTypography.sectionHeader()),
        const SizedBox(height: Space.x1),
        Text(
          'Money moved between your own accounts — this never counts as '
          'spend or income.',
          style: AppTypography.metadata(color: colors.onSurfaceVariant),
        ),
        const SizedBox(height: Space.x2),
        DropdownButtonFormField<String>(
          initialValue: _fromAccountId,
          decoration: const InputDecoration(labelText: 'From'),
          items: [
            for (final account in accounts)
              DropdownMenuItem(value: account.id, child: Text(account.name)),
          ],
          onChanged: (value) => setState(() {
            _fromAccountId = value;
            if (_toAccountId == value) _toAccountId = null;
          }),
        ),
        const SizedBox(height: Space.x2),
        DropdownButtonFormField<String>(
          initialValue: _toAccountId,
          decoration: const InputDecoration(labelText: 'To'),
          items: [
            for (final account in accounts)
              if (account.id != _fromAccountId)
                DropdownMenuItem(value: account.id, child: Text(account.name)),
          ],
          onChanged: (value) => setState(() => _toAccountId = value),
        ),
        const SizedBox(height: Space.x2),
        AmountField(controller: _amountController, errorText: _error),
        const SizedBox(height: Space.x2),
        AmountField(
          controller: _feeController,
          label: 'Fee (optional)',
        ),
        const SizedBox(height: Space.x1),
        AppListRow(
          title: const Text('Date'),
          subtitle: Text(_transactedAt.toString().split('.').first),
          trailing: AppIcon(
            AppIcons.chevronRight,
            size: 18,
            color: colors.onSurfaceVariant,
          ),
          onTap: _pickDate,
        ),
        const SizedBox(height: Space.x2),
        AppButton.primary(label: 'Record transfer', onPressed: _save),
      ],
    );
  }
}

class NoAccountsYet extends StatelessWidget {
  const NoAccountsYet({super.key});

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: AppIcons.emptyWallet,
      title: 'No accounts yet',
      message: 'Add a cash wallet, bank account, or mobile money account to '
          'record transactions against.',
      actionLabel: 'Add account',
      onAction: () => AccountEditorSheet.show(context),
    );
  }
}
