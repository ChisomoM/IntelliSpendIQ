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
    this.payeeId,
    this.labelIds = const [],
    this.isPaid = true,
    this.categories = const [],
    this.accounts = const [],
    this.payees = const [],
    this.labels = const [],
    this.receiptPath,
    this.errorMessage,
  });

  final TransactionEntryStatus status;
  final String amount;
  final String merchant;
  final String description;
  final TxDirection direction;
  final String? categoryId;
  final String? accountId;

  /// Structured payee, when one was picked rather than left as free
  /// text in [merchant].
  final String? payeeId;

  /// Labels attached to this transaction.
  final List<String> labelIds;

  /// "Mark as paid" — unchecked records the transaction as
  /// [TxStatus.planned] rather than confirmed, excluded from totals
  /// until it's later marked paid.
  final bool isPaid;
  final DateTime transactedAt;
  final List<Category> categories;
  final List<Account> accounts;
  final List<Payee> payees;
  final List<Label> labels;

  /// App-local path to an attached receipt photo, if any.
  final String? receiptPath;
  final String? errorMessage;

  bool get isSaving => status == TransactionEntryStatus.saving;

  /// Categories of the direction currently selected — a debit entry
  /// should not offer income categories, which the old flat dropdown
  /// did.
  List<Category> get categoriesForDirection {
    final wanted = direction == TxDirection.credit
        ? CategoryType.income
        : CategoryType.expense;
    return categories.where((c) => c.type == wanted).toList();
  }

  /// True when the entry has enough to be saved.
  bool get canSave => Money.tryParseToMinor(amount) != null;

  /// Whether [transactedAt] falls on [day], for the date shortcuts.
  bool isOnDay(DateTime day) =>
      transactedAt.year == day.year &&
      transactedAt.month == day.month &&
      transactedAt.day == day.day;

  TransactionEntryState copyWith({
    TransactionEntryStatus? status,
    String? amount,
    String? merchant,
    String? description,
    TxDirection? direction,
    String? categoryId,
    String? accountId,
    String? payeeId,
    bool clearPayee = false,
    List<String>? labelIds,
    bool? isPaid,
    DateTime? transactedAt,
    List<Category>? categories,
    List<Account>? accounts,
    List<Payee>? payees,
    List<Label>? labels,
    String? receiptPath,
    bool clearReceiptPath = false,
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
      payeeId: clearPayee ? null : (payeeId ?? this.payeeId),
      labelIds: labelIds ?? this.labelIds,
      isPaid: isPaid ?? this.isPaid,
      transactedAt: transactedAt ?? this.transactedAt,
      categories: categories ?? this.categories,
      accounts: accounts ?? this.accounts,
      payees: payees ?? this.payees,
      labels: labels ?? this.labels,
      receiptPath: clearReceiptPath ? null : (receiptPath ?? this.receiptPath),
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
    payeeId,
    labelIds,
    isPaid,
    transactedAt,
    categories,
    accounts,
    payees,
    labels,
    receiptPath,
    errorMessage,
  ];
}
