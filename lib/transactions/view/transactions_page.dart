import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intellispendiq/data/repositories/account_repository.dart';
import 'package:intellispendiq/data/repositories/category_repository.dart';
import 'package:intellispendiq/data/repositories/transaction_repository.dart';
import 'package:intellispendiq/domain/models/transaction.dart';
import 'package:intellispendiq/transactions/cubit/cubit.dart';
import 'package:intellispendiq/transactions/widgets/widgets.dart';

class TransactionsPage extends StatelessWidget {
  const TransactionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => TransactionsCubit(
        transactions: context.read<TransactionRepository>(),
        categories: context.read<CategoryRepository>(),
        accounts: context.read<AccountRepository>(),
      )..subscribeUnawaited(),
      child: const TransactionsView(),
    );
  }
}

class TransactionsView extends StatefulWidget {
  const TransactionsView({super.key});

  @override
  State<TransactionsView> createState() => _TransactionsViewState();
}

class _TransactionsViewState extends State<TransactionsView> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(
      text: context.read<TransactionsCubit>().state.query,
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<TransactionsCubit>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Activity'),
        actions: [
          BlocBuilder<TransactionsCubit, TransactionsState>(
            buildWhen: (previous, current) =>
                previous.hasFilters != current.hasFilters,
            builder: (context, state) {
              return IconButton(
                icon: Badge(
                  isLabelVisible: state.hasFilters,
                  child: const Icon(Icons.filter_list),
                ),
                tooltip: 'Filter',
                onPressed: () => TransactionFilterSheet.show(context),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: BlocBuilder<TransactionsCubit, TransactionsState>(
              buildWhen: (previous, current) => previous.query != current.query,
              builder: (context, state) {
                if (_searchController.text != state.query) {
                  _searchController.text = state.query;
                }
                return TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search merchant or note',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: state.query.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () => cubit.queryChanged(''),
                          ),
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onChanged: cubit.queryChanged,
                );
              },
            ),
          ),
          Expanded(
            child: BlocBuilder<TransactionsCubit, TransactionsState>(
              builder: (context, state) {
                if (state.isEmpty && !state.hasFilters) {
                  return const NoTransactionsYet();
                }
                if (state.isEmpty) {
                  return const _NoMatchingTransactions();
                }

                return ListView.separated(
                  padding: const EdgeInsets.only(bottom: 96),
                  itemCount: state.transactions.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final transaction = state.transactions[index];
                    return Dismissible(
                      key: ValueKey(transaction.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        color: Theme.of(context).colorScheme.errorContainer,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Icon(
                          Icons.delete_outline,
                          color: Theme.of(context).colorScheme.onErrorContainer,
                        ),
                      ),
                      confirmDismiss: (_) =>
                          _confirmDelete(context, transaction),
                      onDismissed: (_) => context
                          .read<TransactionsCubit>()
                          .delete(transaction.id),
                      child: TransactionTile(transaction: transaction),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<bool> _confirmDelete(
    BuildContext context,
    Transaction transaction,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete this transaction?'),
        content: Text(
          transaction.merchant?.isNotEmpty ?? false
              ? 'This removes the entry for "${transaction.merchant}". '
                    'This cannot be undone.'
              : 'This removes the entry. This cannot be undone.',
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
    return confirmed ?? false;
  }
}

class _NoMatchingTransactions extends StatelessWidget {
  const _NoMatchingTransactions();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_off, size: 48),
            const SizedBox(height: 16),
            const Text(
              'No matching transactions',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Try a different search term or clear your filters.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: context.read<TransactionsCubit>().clearFilters,
              child: const Text('Clear filters'),
            ),
          ],
        ),
      ),
    );
  }
}
