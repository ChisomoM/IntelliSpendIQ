import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intellispendiq/accounts/cubit/cubit.dart';
import 'package:intellispendiq/core/money.dart';
import 'package:intellispendiq/domain/models/account.dart';
import 'package:intellispendiq/domain/models/enums.dart';

String accountTypeLabel(AccountType type) => switch (type) {
  AccountType.cash => 'Cash',
  AccountType.bank => 'Bank',
  AccountType.mobileMoney => 'Mobile Money',
  AccountType.card => 'Card',
};

IconData accountTypeIcon(AccountType type) => switch (type) {
  AccountType.cash => Icons.payments_outlined,
  AccountType.bank => Icons.account_balance_outlined,
  AccountType.mobileMoney => Icons.phone_iphone,
  AccountType.card => Icons.credit_card_outlined,
};

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
    return ListTile(
      leading: CircleAvatar(child: Icon(accountTypeIcon(account.type))),
      title: Text(account.name),
      subtitle: Text(
        '${accountTypeLabel(account.type)} · '
        '${Money.format(balanceMinor, currency: account.currency)}',
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(account.isDefault ? Icons.star : Icons.star_border),
            tooltip: account.isDefault ? 'Default account' : 'Set as default',
            color: account.isDefault
                ? Theme.of(context).colorScheme.primary
                : null,
            onPressed: account.isDefault
                ? null
                : () => context.read<AccountsCubit>().setDefault(account.id),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit balance',
            onPressed: () => BalanceEditorSheet.show(
              context,
              account: account,
              currentBalanceMinor: balanceMinor,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Delete',
            onPressed: () => _confirmDelete(context),
          ),
        ],
      ),
    );
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

/// Adds a new account. There is deliberately no edit path here — a
/// mistaken account is deleted and re-added rather than renamed.
class AccountEditorSheet extends StatefulWidget {
  const AccountEditorSheet({super.key});

  static Future<void> show(BuildContext context) {
    final cubit = context.read<AccountsCubit>();
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
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
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Add account', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          TextField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: 'Account name',
              errorText: _error,
            ),
            textCapitalization: TextCapitalization.words,
            autofocus: true,
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<AccountType>(
            initialValue: _type,
            decoration: const InputDecoration(labelText: 'Type'),
            items: [
              for (final type in AccountType.values)
                DropdownMenuItem(
                  value: type,
                  child: Text(accountTypeLabel(type)),
                ),
            ],
            onChanged: (value) => setState(() => _type = value ?? _type),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _openingBalanceController,
            decoration: const InputDecoration(
              labelText: 'Opening balance (optional)',
              helperText:
                  'What it holds right now — leave blank to start '
                  'from zero and log transactions as they happen',
              prefixText: 'ZMW ',
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp('[0-9.,]')),
            ],
          ),
          const SizedBox(height: 24),
          FilledButton(onPressed: _save, child: const Text('Add account')),
        ],
      ),
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
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
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
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Edit balance for ${widget.account.name}',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _amountController,
            decoration: InputDecoration(
              labelText: 'Balance',
              prefixText: '${widget.account.currency} ',
              errorText: _error,
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp('[0-9.,]')),
            ],
            autofocus: true,
          ),
          const SizedBox(height: 24),
          FilledButton(onPressed: _save, child: const Text('Save')),
        ],
      ),
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
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
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
  String? _fromAccountId;
  String? _toAccountId;
  DateTime _transactedAt = DateTime.now();
  String? _error;

  @override
  void dispose() {
    _amountController.dispose();
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
    if (accounts.length < 2) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'Add a second account before recording a transfer between them.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Record a transfer',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 4),
          Text(
            'Money moved between your own accounts — this never counts '
            'as spend or income.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
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
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _toAccountId,
            decoration: const InputDecoration(labelText: 'To'),
            items: [
              for (final account in accounts)
                if (account.id != _fromAccountId)
                  DropdownMenuItem(
                    value: account.id,
                    child: Text(account.name),
                  ),
            ],
            onChanged: (value) => setState(() => _toAccountId = value),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _amountController,
            decoration: InputDecoration(
              labelText: 'Amount',
              prefixText: 'ZMW ',
              errorText: _error,
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp('[0-9.,]')),
            ],
            autofocus: true,
          ),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Date'),
            subtitle: Text(_transactedAt.toString().split('.').first),
            trailing: const Icon(Icons.chevron_right),
            onTap: _pickDate,
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _save,
            child: const Text('Record transfer'),
          ),
        ],
      ),
    );
  }
}

class NoAccountsYet extends StatelessWidget {
  const NoAccountsYet({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.account_balance_wallet_outlined, size: 48),
            const SizedBox(height: 16),
            const Text(
              'No accounts yet',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Add a cash wallet, bank account, or mobile money account '
              'to record transactions against.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => AccountEditorSheet.show(context),
              child: const Text('Add account'),
            ),
          ],
        ),
      ),
    );
  }
}
