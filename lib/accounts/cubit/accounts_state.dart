part of 'accounts_cubit.dart';

enum AccountsStatus { initial, loading, loaded, invalid }

class AccountsState extends Equatable {
  const AccountsState({
    this.status = AccountsStatus.initial,
    this.accounts = const [],
    this.computedBalances = const {},
    this.errorMessage,
  });

  final AccountsStatus status;
  final List<Account> accounts;

  /// Each account's live balance — its last manual checkpoint plus
  /// every confirmed transaction/transfer since. Keyed by account id;
  /// an id missing here (before the first emission arrives) reads as
  /// zero via [balanceFor].
  final Map<String, int> computedBalances;

  final String? errorMessage;

  bool get isEmpty => status == AccountsStatus.loaded && accounts.isEmpty;

  int balanceFor(String accountId) => computedBalances[accountId] ?? 0;

  /// Every account's live balance summed, in ngwee.
  int get totalBalanceMinor =>
      accounts.fold(0, (sum, account) => sum + balanceFor(account.id));

  /// Accounts grouped by type, in a stable display order.
  Map<AccountType, List<Account>> get byType {
    final grouped = <AccountType, List<Account>>{};
    for (final type in AccountType.values) {
      final matching = accounts.where((a) => a.type == type).toList();
      if (matching.isNotEmpty) grouped[type] = matching;
    }
    return grouped;
  }

  AccountsState copyWith({
    AccountsStatus? status,
    List<Account>? accounts,
    Map<String, int>? computedBalances,
    String? errorMessage,
  }) {
    return AccountsState(
      status: status ?? this.status,
      accounts: accounts ?? this.accounts,
      computedBalances: computedBalances ?? this.computedBalances,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, accounts, computedBalances, errorMessage];
}
