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
