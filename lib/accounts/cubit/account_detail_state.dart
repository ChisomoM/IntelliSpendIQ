part of 'account_detail_cubit.dart';

enum AccountDetailStatus { initial, loading, loaded, notFound }

class AccountDetailState extends Equatable {
  const AccountDetailState({
    required this.accountId,
    this.status = AccountDetailStatus.initial,
    this.account,
    this.accounts = const [],
    this.balanceMinor = 0,
    this.transactions = const [],
    this.transfers = const [],
    this.categories = const [],
  });

  final String accountId;
  final AccountDetailStatus status;
  final Account? account;

  /// Every live account — used to name the other side of a transfer.
  final List<Account> accounts;
  final int balanceMinor;
  final List<Transaction> transactions;

  /// Transfers that credit or debit [accountId], already filtered.
  final List<Transfer> transfers;
  final List<Category> categories;

  bool get isEmpty => status == AccountDetailStatus.loaded && feed.isEmpty;

  /// Confirmed credits on this account. Transfers are excluded — they
  /// move money the user already had, so they are not income.
  int get moneyInMinor => transactions
      .where(
        (t) =>
            t.direction == TxDirection.credit && t.status == TxStatus.confirmed,
      )
      .fold(0, (sum, t) => sum + t.amountMinor);

  /// Confirmed debits on this account. Transfers are excluded — they
  /// are not spend.
  int get moneyOutMinor => transactions
      .where(
        (t) =>
            t.direction == TxDirection.debit && t.status == TxStatus.confirmed,
      )
      .fold(0, (sum, t) => sum + t.amountMinor);

  Map<String, Category> get categoriesById => {
    for (final category in categories) category.id: category,
  };

  Map<String, String> get accountNames => {
    for (final account in accounts) account.id: account.name,
  };

  /// Transactions and transfers on this account, newest first.
  List<ActivityEntry> get feed {
    final entries = <ActivityEntry>[
      for (final transaction in transactions) TransactionEntry(transaction),
      for (final transfer in transfers) TransferEntry(transfer),
    ]..sort((a, b) => b.transactedAt.compareTo(a.transactedAt));
    return entries;
  }

  /// [feed] split into local calendar days. Unlike the global Activity
  /// feed, a day's net here includes transfers — moving money in or out
  /// of *this* account does change what it holds, even though it does
  /// not change the household total.
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
          netMinor: buckets[day]!.fold(0, (sum, entry) => sum + _signed(entry)),
        ),
    ];
  }

  int _signed(ActivityEntry entry) {
    return switch (entry) {
      TransactionEntry(:final transaction) =>
        transaction.direction == TxDirection.credit
            ? transaction.amountMinor
            : -transaction.amountMinor,
      TransferEntry(:final transfer) =>
        transfer.toAccountId == accountId
            ? transfer.amountMinor
            : -transfer.amountMinor,
    };
  }

  AccountDetailState copyWith({
    AccountDetailStatus? status,
    Account? account,
    List<Account>? accounts,
    int? balanceMinor,
    List<Transaction>? transactions,
    List<Transfer>? transfers,
    List<Category>? categories,
  }) {
    return AccountDetailState(
      accountId: accountId,
      status: status ?? this.status,
      account: account ?? this.account,
      accounts: accounts ?? this.accounts,
      balanceMinor: balanceMinor ?? this.balanceMinor,
      transactions: transactions ?? this.transactions,
      transfers: transfers ?? this.transfers,
      categories: categories ?? this.categories,
    );
  }

  @override
  List<Object?> get props => [
    accountId,
    status,
    account,
    accounts,
    balanceMinor,
    transactions,
    transfers,
    categories,
  ];
}
