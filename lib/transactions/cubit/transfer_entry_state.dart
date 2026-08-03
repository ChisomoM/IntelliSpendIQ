part of 'transfer_entry_cubit.dart';

enum TransferEntryStatus { editing, invalid, saving, saved, deleted, failure }

class TransferEntryState extends Equatable {
  const TransferEntryState({
    required this.transactedAt,
    this.status = TransferEntryStatus.editing,
    this.fromAccountId,
    this.toAccountId,
    this.amount = '',
    this.fee = '',
    this.note = '',
    this.accounts = const [],
    this.errorMessage,
  });

  final TransferEntryStatus status;
  final String? fromAccountId;
  final String? toAccountId;
  final String amount;
  final String fee;
  final String note;
  final DateTime transactedAt;
  final List<Account> accounts;
  final String? errorMessage;

  bool get isSaving => status == TransferEntryStatus.saving;

  bool get canSave => Money.tryParseToMinor(amount) != null;

  TransferEntryState copyWith({
    TransferEntryStatus? status,
    String? fromAccountId,
    String? toAccountId,
    String? amount,
    String? fee,
    String? note,
    DateTime? transactedAt,
    List<Account>? accounts,
    String? errorMessage,
  }) {
    return TransferEntryState(
      status: status ?? this.status,
      fromAccountId: fromAccountId ?? this.fromAccountId,
      toAccountId: toAccountId ?? this.toAccountId,
      amount: amount ?? this.amount,
      fee: fee ?? this.fee,
      note: note ?? this.note,
      transactedAt: transactedAt ?? this.transactedAt,
      accounts: accounts ?? this.accounts,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [
    status,
    fromAccountId,
    toAccountId,
    amount,
    fee,
    note,
    transactedAt,
    accounts,
    errorMessage,
  ];
}
