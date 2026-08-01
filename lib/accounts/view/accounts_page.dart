import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intellispendiq/accounts/cubit/cubit.dart';
import 'package:intellispendiq/accounts/widgets/widgets.dart';
import 'package:intellispendiq/data/repositories/account_repository.dart';
import 'package:intellispendiq/data/repositories/transfer_repository.dart';
import 'package:intellispendiq/design/design.dart';

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
            icon: AppIcon(AppIcons.transfer, size: 22),
            tooltip: 'Record transfer',
            onPressed: () => RecordTransferSheet.show(context),
          ),
          IconButton(
            icon: AppIcon(AppIcons.add, size: 22),
            tooltip: 'Add account',
            onPressed: () => AccountEditorSheet.show(context),
          ),
          const SizedBox(width: Space.x1),
        ],
      ),
      body: BlocBuilder<AccountsCubit, AccountsState>(
        builder: (context, state) {
          if (state.isEmpty) return const NoAccountsYet();
          if (state.status == AccountsStatus.initial ||
              state.status == AccountsStatus.loading) {
            return const Center(child: CircularProgressIndicator());
          }

          final colors = Theme.of(context).colorScheme;
          final byType = state.byType;

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
                      'TOTAL BALANCE',
                      style: AppTypography.chipOverline(
                        color: AppColors.nightText2,
                      ),
                    ),
                    const SizedBox(height: Space.x1),
                    MoneyText(
                      state.totalBalanceMinor,
                      size: MoneySize.display,
                      color: AppColors.nightText,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: Space.sectionGap),
              for (final entry in byType.entries) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 0, 4, Space.x1),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          accountTypeLabel(entry.key),
                          style: AppTypography.sectionHeader(
                            color: colors.onSurface,
                          ),
                        ),
                      ),
                      MoneyText(
                        entry.value.fold(
                          0,
                          (sum, a) => sum + state.balanceFor(a.id),
                        ),
                        size: MoneySize.meta,
                      ),
                    ],
                  ),
                ),
                for (final account in entry.value)
                  AccountTile(
                    account: account,
                    balanceMinor: state.balanceFor(account.id),
                  ),
                const SizedBox(height: Space.x1),
              ],
            ],
          );
        },
      ),
    );
  }
}
