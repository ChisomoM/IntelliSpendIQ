import 'package:equatable/equatable.dart';

/// Money moved between two of the user's own accounts — e.g. a bank
/// withdrawal into mobile money. Kept separate from [Transaction] so it
/// never counts toward spend or income totals.
class Transfer extends Equatable {
  const Transfer({
    required this.id,
    required this.fromAccountId,
    required this.toAccountId,
    required this.amountMinor,
    required this.transactedAt,
    this.note,
  });

  final String id;
  final String fromAccountId;
  final String toAccountId;
  final int amountMinor;
  final DateTime transactedAt;
  final String? note;

  @override
  List<Object?> get props => [
    id,
    fromAccountId,
    toAccountId,
    amountMinor,
    transactedAt,
    note,
  ];
}
