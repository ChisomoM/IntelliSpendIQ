part of 'accounts_cubit.dart';

enum AccountsStatus { initial, loading, loaded, invalid }

class AccountsState extends Equatable {
  const AccountsState({
    this.status = AccountsStatus.initial,
    this.accounts = const [],
    this.errorMessage,
  });

  final AccountsStatus status;
  final List<Account> accounts;
  final String? errorMessage;

  bool get isEmpty => status == AccountsStatus.loaded && accounts.isEmpty;

  /// Every account's balance summed, in ngwee. Accounts with no known
  /// balance (never reported by a provider or set by hand) count as
  /// zero.
  int get totalBalanceMinor =>
      accounts.fold(0, (sum, account) => sum + (account.balanceMinor ?? 0));

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
    String? errorMessage,
  }) {
    return AccountsState(
      status: status ?? this.status,
      accounts: accounts ?? this.accounts,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, accounts, errorMessage];
}
