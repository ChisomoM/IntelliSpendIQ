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
  const AccountTile({required this.account, super.key});

  final Account account;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(child: Icon(accountTypeIcon(account.type))),
      title: Text(account.name),
      subtitle: Text(
        account.balanceMinor == null
            ? accountTypeLabel(account.type)
            : '${accountTypeLabel(account.type)} · ${Money.format(account.balanceMinor!, currency: account.currency)}',
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (account.isDefault)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Icon(
                Icons.star,
                size: 18,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit balance',
            onPressed: () => BalanceEditorSheet.show(context, account: account),
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
  AccountType _type = AccountType.mobileMoney;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final navigator = Navigator.of(context);
    await context.read<AccountsCubit>().add(
      name: _nameController.text,
      type: _type,
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
          const SizedBox(height: 24),
          FilledButton(onPressed: _save, child: const Text('Add account')),
        ],
      ),
    );
  }
}

/// Sets an account's balance by hand — the same figure SMS parsing
/// keeps current automatically, but editable directly for an account
/// with no linked provider, or just to correct it.
class BalanceEditorSheet extends StatefulWidget {
  const BalanceEditorSheet({required this.account, super.key});

  final Account account;

  static Future<void> show(BuildContext context, {required Account account}) {
    final cubit = context.read<AccountsCubit>();
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => BlocProvider.value(
        value: cubit,
        child: BalanceEditorSheet(account: account),
      ),
    );
  }

  @override
  State<BalanceEditorSheet> createState() => _BalanceEditorSheetState();
}

class _BalanceEditorSheetState extends State<BalanceEditorSheet> {
  late final TextEditingController _amountController = TextEditingController(
    text: widget.account.balanceMinor == null
        ? ''
        : (widget.account.balanceMinor! / 100).toStringAsFixed(2),
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
