part of 'transactions_cubit.dart';

enum TransactionsStatus { initial, loading, loaded }

class TransactionsState extends Equatable {
  const TransactionsState({
    this.status = TransactionsStatus.initial,
    this.transactions = const [],
    this.transfers = const [],
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
  final List<Transfer> transfers;

  /// For the filter sheet's category/account pickers.
  final List<Category> categories;
  final List<Account> accounts;

  final String query;
  final String? categoryId;
  final String? accountId;
  final DateTime? dateFrom;
  final DateTime? dateTo;

  bool get isEmpty => status == TransactionsStatus.loaded && feed.isEmpty;

  bool get hasFilters =>
      query.isNotEmpty ||
      categoryId != null ||
      accountId != null ||
      dateFrom != null ||
      dateTo != null;

  /// Transfers matching the account and date filters — transfers have
  /// no category or merchant, so a query or category filter excludes
  /// them entirely rather than trying to match against nothing.
  List<Transfer> get visibleTransfers {
    if (query.isNotEmpty || categoryId != null) return const [];
    return transfers.where((transfer) {
      if (accountId != null &&
          transfer.fromAccountId != accountId &&
          transfer.toAccountId != accountId) {
        return false;
      }
      if (dateFrom != null &&
          transfer.transactedAt.isBefore(dateFrom!.toUtc())) {
        return false;
      }
      if (dateTo != null &&
          !transfer.transactedAt.isBefore(
            dateTo!.toUtc().add(const Duration(days: 1)),
          )) {
        return false;
      }
      return true;
    }).toList();
  }

  /// Transactions and transfers merged into one date-sorted feed, so a
  /// linked transfer stays visible in history instead of disappearing
  /// once its two original legs are soft-deleted.
  List<ActivityEntry> get feed {
    final entries = <ActivityEntry>[
      for (final transaction in transactions) TransactionEntry(transaction),
      for (final transfer in visibleTransfers) TransferEntry(transfer),
    ]..sort((a, b) => b.transactedAt.compareTo(a.transactedAt));
    return entries;
  }

  TransactionsState copyWith({
    TransactionsStatus? status,
    List<Transaction>? transactions,
    List<Transfer>? transfers,
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
      transfers: transfers ?? this.transfers,
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
    transfers,
    categories,
    accounts,
    query,
    categoryId,
    accountId,
    dateFrom,
    dateTo,
  ];
}
