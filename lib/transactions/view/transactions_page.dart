import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intellispendiq/data/repositories/transaction_repository.dart';
import 'package:intellispendiq/transactions/cubit/cubit.dart';
import 'package:intellispendiq/transactions/widgets/widgets.dart';

class TransactionsPage extends StatelessWidget {
  const TransactionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          TransactionsCubit(context.read<TransactionRepository>())..subscribe(),
      child: const TransactionsView(),
    );
  }
}

class TransactionsView extends StatelessWidget {
  const TransactionsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Activity')),
      body: BlocBuilder<TransactionsCubit, TransactionsState>(
        builder: (context, state) {
          if (state.isEmpty) return const NoTransactionsYet();

          return ListView.separated(
            padding: const EdgeInsets.only(bottom: 96),
            itemCount: state.transactions.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) =>
                TransactionTile(transaction: state.transactions[index]),
          );
        },
      ),
    );
  }
}
