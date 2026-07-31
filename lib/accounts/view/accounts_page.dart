import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intellispendiq/accounts/cubit/cubit.dart';
import 'package:intellispendiq/accounts/widgets/widgets.dart';
import 'package:intellispendiq/core/money.dart';
import 'package:intellispendiq/data/repositories/account_repository.dart';
import 'package:intellispendiq/data/repositories/transfer_repository.dart';

class AccountsPage extends StatelessWidget {
  const AccountsPage({super.key});

  static Route<void> route() {
    return MaterialPageRoute<void>(builder: (_) => const AccountsPage());
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => AccountsCubit(
        context.read<AccountRepository>(),
        context.read<TransferRepository>(),
      )..loadUnawaited(),
      child: const AccountsView(),
    );
  }
}

class AccountsView extends StatelessWidget {
  const AccountsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Accounts'),
        actions: [
          IconButton(
            icon: const Icon(Icons.swap_horiz),
            tooltip: 'Record transfer',
            onPressed: () => RecordTransferSheet.show(context),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add account',
            onPressed: () => AccountEditorSheet.show(context),
          ),
        ],
      ),
      body: BlocBuilder<AccountsCubit, AccountsState>(
        builder: (context, state) {
          if (state.isEmpty) return const NoAccountsYet();
          if (state.status == AccountsStatus.initial ||
              state.status == AccountsStatus.loading) {
            return const Center(child: CircularProgressIndicator());
          }

          final theme = Theme.of(context);
          final byType = state.byType;

          return ListView(
            children: [
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    colors: [
                      theme.colorScheme.primary,
                      theme.colorScheme.primaryContainer,
                    ],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total balance',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      Money.format(state.totalBalanceMinor),
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: theme.colorScheme.onPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              for (final entry in byType.entries) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          accountTypeLabel(entry.key),
                          style: theme.textTheme.titleSmall,
                        ),
                      ),
                      Text(
                        Money.format(
                          entry.value.fold(
                            0,
                            (sum, a) => sum + state.balanceFor(a.id),
                          ),
                        ),
                        style: theme.textTheme.titleSmall,
                      ),
                    ],
                  ),
                ),
                for (final account in entry.value)
                  AccountTile(
                    account: account,
                    balanceMinor: state.balanceFor(account.id),
                  ),
                const Divider(height: 1),
              ],
              const SizedBox(height: 80),
            ],
          );
        },
      ),
    );
  }
}
