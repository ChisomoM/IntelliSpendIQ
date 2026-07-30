part of 'transactions_cubit.dart';

enum TransactionsStatus { initial, loading, loaded }

class TransactionsState extends Equatable {
  const TransactionsState({
    this.status = TransactionsStatus.initial,
    this.transactions = const [],
    this.categories = const [],
    this.accounts = const [],
    this.query = '',
    this.categoryId,
    this.accountId,
    this.dateFrom,
    this.dateTo,
  });

  final TransactionsStatus status;
  final List<Transaction> transactions;

  /// For the filter sheet's category/account pickers.
  final List<Category> categories;
  final List<Account> accounts;

  final String query;
  final String? categoryId;
  final String? accountId;
  final DateTime? dateFrom;
  final DateTime? dateTo;

  bool get isEmpty =>
      status == TransactionsStatus.loaded && transactions.isEmpty;

  bool get hasFilters =>
      query.isNotEmpty ||
      categoryId != null ||
      accountId != null ||
      dateFrom != null ||
      dateTo != null;

  TransactionsState copyWith({
    TransactionsStatus? status,
    List<Transaction>? transactions,
    List<Category>? categories,
    List<Account>? accounts,
    String? query,
    String? categoryId,
    bool clearCategoryId = false,
    String? accountId,
    bool clearAccountId = false,
    DateTime? dateFrom,
    bool clearDateFrom = false,
    DateTime? dateTo,
    bool clearDateTo = false,
  }) {
    return TransactionsState(
      status: status ?? this.status,
      transactions: transactions ?? this.transactions,
      categories: categories ?? this.categories,
      accounts: accounts ?? this.accounts,
      query: query ?? this.query,
      categoryId: clearCategoryId ? null : (categoryId ?? this.categoryId),
      accountId: clearAccountId ? null : (accountId ?? this.accountId),
      dateFrom: clearDateFrom ? null : (dateFrom ?? this.dateFrom),
      dateTo: clearDateTo ? null : (dateTo ?? this.dateTo),
    );
  }

  @override
  List<Object?> get props => [
    status,
    transactions,
    categories,
    accounts,
    query,
    categoryId,
    accountId,
    dateFrom,
    dateTo,
  ];
}
