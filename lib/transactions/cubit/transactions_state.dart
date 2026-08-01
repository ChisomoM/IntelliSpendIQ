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
    this.direction,
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

  /// Money in / money out, from the chip row above the list. Applied
  /// here rather than in the query: the feed is already capped, and a
  /// transfer is neither direction, which a SQL predicate on
  /// `transactions` alone could not express.
  final TxDirection? direction;

  bool get isEmpty => status == TransactionsStatus.loaded && feed.isEmpty;

  bool get hasFilters =>
      query.isNotEmpty ||
      categoryId != null ||
      accountId != null ||
      dateFrom != null ||
      dateTo != null ||
      direction != null;

  /// Filters set in the sheet rather than the chip row — the chip row
  /// shows its own state, so the sheet's badge should not light up for
  /// it as well.
  bool get hasSheetFilters =>
      categoryId != null ||
      accountId != null ||
      dateFrom != null ||
      dateTo != null;

  /// Transfers matching the account and date filters — transfers have
  /// no category or merchant, so a query or category filter excludes
  /// them entirely rather than trying to match against nothing.
  List<Transfer> get visibleTransfers {
    // A transfer is neither money in nor money out, so either
    // direction filter excludes it rather than picking a side.
    if (query.isNotEmpty || categoryId != null || direction != null) {
      return const [];
    }
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
      for (final transaction in transactions)
        if (direction == null || transaction.direction == direction)
          TransactionEntry(transaction),
      for (final transfer in visibleTransfers) TransferEntry(transfer),
    ]..sort((a, b) => b.transactedAt.compareTo(a.transactedAt));
    return entries;
  }

  /// [feed] split into local calendar days, newest first, each with the
  /// day's net movement for its header.
  List<ActivityDayGroup> get dayGroups {
    final buckets = <DateTime, List<ActivityEntry>>{};
    for (final entry in feed) {
      final local = entry.transactedAt.toLocal();
      final day = DateTime(local.year, local.month, local.day);
      buckets.putIfAbsent(day, () => []).add(entry);
    }

    final days = buckets.keys.toList()..sort((a, b) => b.compareTo(a));
    return [
      for (final day in days)
        ActivityDayGroup(
          day: day,
          entries: buckets[day]!,
          netMinor: buckets[day]!.fold(0, (sum, entry) {
            if (entry is! TransactionEntry) return sum;
            final transaction = entry.transaction;
            return transaction.direction == TxDirection.credit
                ? sum + transaction.amountMinor
                : sum - transaction.amountMinor;
          }),
        ),
    ];
  }

  /// Icon key per category id, so a row can render its avatar from the
  /// category id a [Transaction] carries.
  Map<String, String?> get categoryIcons => {
    for (final category in categories) category.id: category.icon,
  };

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
    TxDirection? direction,
    bool clearDirection = false,
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
      direction: clearDirection ? null : (direction ?? this.direction),
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
    direction,
  ];
}
