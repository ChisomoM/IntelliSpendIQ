import 'package:equatable/equatable.dart';

/// Per-period category envelope (expense limit or income plan), in ngwee.
class CategoryBudget extends Equatable {
  const CategoryBudget({
    required this.id,
    required this.periodId,
    required this.categoryId,
    required this.amountMinor,
  });

  final String id;
  final String periodId;
  final String categoryId;
  final int amountMinor;

  @override
  List<Object?> get props => [id, periodId, categoryId, amountMinor];
}
