import 'package:equatable/equatable.dart';
import 'package:intellispendiq/domain/models/enums.dart';

/// Per-period category envelope (expense limit or income plan), in ngwee.
class CategoryBudget extends Equatable {
  const CategoryBudget({
    required this.id,
    required this.periodId,
    required this.categoryId,
    required this.amountMinor,
    this.status,
    this.transactionId,
  });

  final String id;
  final String periodId;
  final String categoryId;
  final int amountMinor;

  /// Only meaningful for income-type categories. Null for expense
  /// envelopes, which have no paid/unpaid concept.
  final IncomeStatus? status;

  /// The transaction backing this envelope when [status] is
  /// [IncomeStatus.paid]. Null otherwise.
  final String? transactionId;

  bool get isPaid => status == IncomeStatus.paid;

  @override
  List<Object?> get props => [
    id,
    periodId,
    categoryId,
    amountMinor,
    status,
    transactionId,
  ];
}
