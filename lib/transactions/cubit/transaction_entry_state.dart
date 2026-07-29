part of 'transaction_entry_cubit.dart';

enum TransactionEntryStatus { editing, invalid, saving, saved, failure }

class TransactionEntryState extends Equatable {
  const TransactionEntryState({
    required this.transactedAt,
    this.status = TransactionEntryStatus.editing,
    this.amount = '',
    this.merchant = '',
    this.description = '',
    this.direction = TxDirection.debit,
    this.categoryId,
    this.accountId,
    this.categories = const [],
    this.accounts = const [],
    this.errorMessage,
  });

  final TransactionEntryStatus status;
  final String amount;
  final String merchant;
  final String description;
  final TxDirection direction;
  final String? categoryId;
  final String? accountId;
  final DateTime transactedAt;
  final List<CategoryRow> categories;
  final List<AccountRow> accounts;
  final String? errorMessage;

  bool get isSaving => status == TransactionEntryStatus.saving;

  TransactionEntryState copyWith({
    TransactionEntryStatus? status,
    String? amount,
    String? merchant,
    String? description,
    TxDirection? direction,
    String? categoryId,
    String? accountId,
    DateTime? transactedAt,
    List<CategoryRow>? categories,
    List<AccountRow>? accounts,
    String? errorMessage,
  }) {
    return TransactionEntryState(
      status: status ?? this.status,
      amount: amount ?? this.amount,
      merchant: merchant ?? this.merchant,
      description: description ?? this.description,
      direction: direction ?? this.direction,
      categoryId: categoryId ?? this.categoryId,
      accountId: accountId ?? this.accountId,
      transactedAt: transactedAt ?? this.transactedAt,
      categories: categories ?? this.categories,
      accounts: accounts ?? this.accounts,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [
    status,
    amount,
    merchant,
    description,
    direction,
    categoryId,
    accountId,
    transactedAt,
    categories,
    accounts,
    errorMessage,
  ];
}
