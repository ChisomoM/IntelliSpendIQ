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

  /// The label to show for this category.
  ///
  /// This used to prepend [icon] to the name, because [icon] held an
  /// emoji and gluing it on was how a list showed both. [icon] now
  /// holds a `CategoryIconKey` that a `CategoryAvatar` renders as a
  /// real glyph beside the label, so prepending it would print the key
  /// itself — "food Food" — and, worse, send that to the model in the
  /// assistant's category payloads.
  String get displayName => name;

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
