part of 'transactions_cubit.dart';

enum TransactionsStatus { initial, loading, loaded }

class TransactionsState extends Equatable {
  const TransactionsState({
    this.status = TransactionsStatus.initial,
    this.transactions = const [],
  });

  final TransactionsStatus status;
  final List<TransactionRow> transactions;

  bool get isEmpty =>
      status == TransactionsStatus.loaded && transactions.isEmpty;

  TransactionsState copyWith({
    TransactionsStatus? status,
    List<TransactionRow>? transactions,
  }) {
    return TransactionsState(
      status: status ?? this.status,
      transactions: transactions ?? this.transactions,
    );
  }

  @override
  List<Object?> get props => [status, transactions];
}
