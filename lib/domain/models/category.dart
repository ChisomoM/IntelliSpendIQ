import 'package:equatable/equatable.dart';
import 'package:intellispendiq/domain/models/enums.dart';

/// A spending or income category, and — since a category is also the
/// budget line for it — an optional standing monthly figure: a limit
/// for expense categories, a planned amount for income ones.
class Category extends Equatable {
  const Category({
    required this.id,
    required this.name,
    this.icon,
    this.color,
    this.parentId,
    this.isSystem = false,
    this.sortOrder = 0,
    this.type = CategoryType.expense,
    this.budgetedAmountMinor,
  });

  final String id;
  final String name;
  final String? icon;
  final String? color;
  final String? parentId;

  /// Seeded on first launch. Still editable — this only marks origin.
  final bool isSystem;
  final int sortOrder;
  final CategoryType type;

  /// A standing monthly limit (expense) or planned figure (income), in
  /// ngwee. Applies to whichever period is currently viewed.
  final int? budgetedAmountMinor;

  bool get isExpense => type == CategoryType.expense;
  bool get isIncome => type == CategoryType.income;
  bool get hasBudget => budgetedAmountMinor != null;

  /// Icon and name together, the form every list shows. Lived in three
  /// separate widgets before this.
  String get displayName => icon == null ? name : '$icon $name';

  @override
  List<Object?> get props => [
    id,
    name,
    icon,
    color,
    parentId,
    isSystem,
    sortOrder,
    type,
    budgetedAmountMinor,
  ];
}
