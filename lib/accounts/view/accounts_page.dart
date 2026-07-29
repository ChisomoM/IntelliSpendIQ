import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intellispendiq/accounts/cubit/cubit.dart';
import 'package:intellispendiq/accounts/widgets/widgets.dart';
import 'package:intellispendiq/data/repositories/account_repository.dart';

class AccountsPage extends StatelessWidget {
  const AccountsPage({super.key});

  static Route<void> route() {
    return MaterialPageRoute<void>(builder: (_) => const AccountsPage());
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          AccountsCubit(context.read<AccountRepository>())..loadUnawaited(),
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

          return ListView.separated(
            itemCount: state.accounts.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) =>
                AccountTile(account: state.accounts[index]),
          );
        },
      ),
    );
  }
}
