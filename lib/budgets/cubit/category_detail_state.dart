part of 'category_detail_cubit.dart';

enum CategoryDetailStatus { initial, loading, loaded, notFound, invalid }

class CategoryDetailState extends Equatable {
  const CategoryDetailState({
    required this.categoryId,
    required this.periodStartAt,
    required this.periodEndAt,
    this.periodId,
    this.status = CategoryDetailStatus.initial,
    this.category,
    this.allCategories = const [],
    this.children = const [],
    this.directSpentMinor = 0,
    this.directTransactions = const [],
    this.spentByChild = const {},
    this.errorMessage,
  });

  final String categoryId;
  final String? periodId;
  final String periodStartAt;
  final String periodEndAt;
  final CategoryDetailStatus status;
  final Category? category;

  /// Every category — used to offer transfer targets.
  final List<Category> allCategories;
  final List<Category> children;

  /// Spend posted directly against this category — not any of its
  /// subcategories.
  final int directSpentMinor;

  /// The transactions behind [directSpentMinor], most recent first.
  final List<Transaction> directTransactions;
  final Map<String, int> spentByChild;
  final String? errorMessage;

  /// Direct spend plus every subcategory's spend — the figure the
  /// category's own progress bar/gauge tracks against its budget, since
  /// a subcategory's spend still counts against the parent envelope it
  /// was carved out of.
  int get spentMinor =>
      directSpentMinor + spentByChild.values.fold(0, (a, b) => a + b);

  int get budgetedMinor => category?.budgetedAmountMinor ?? 0;
  int get remainingMinor => budgetedMinor - spentMinor;

  /// Sum of subcategory budgets — how much of this category's own
  /// budget has been broken out to children.
  int get totalSubcategoriesBudgetedMinor =>
      children.fold(0, (sum, c) => sum + (c.budgetedAmountMinor ?? 0));

  /// Other top-level categories of the same type, as transfer
  /// targets — moving budget across types (expense vs income) isn't
  /// offered.
  List<Category> get transferTargets => allCategories
      .where(
        (c) =>
            c.id != categoryId &&
            c.parentId == null &&
            c.type == category?.type,
      )
      .toList();

  int spentFor(String childId) => spentByChild[childId] ?? 0;

  CategoryDetailState copyWith({
    CategoryDetailStatus? status,
    Category? category,
    List<Category>? allCategories,
    List<Category>? children,
    int? directSpentMinor,
    List<Transaction>? directTransactions,
    Map<String, int>? spentByChild,
    String? errorMessage,
  }) {
    return CategoryDetailState(
      categoryId: categoryId,
      periodId: periodId,
      periodStartAt: periodStartAt,
      periodEndAt: periodEndAt,
      status: status ?? this.status,
      category: category ?? this.category,
      allCategories: allCategories ?? this.allCategories,
      children: children ?? this.children,
      directSpentMinor: directSpentMinor ?? this.directSpentMinor,
      directTransactions: directTransactions ?? this.directTransactions,
      spentByChild: spentByChild ?? this.spentByChild,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [
    categoryId,
    periodId,
    periodStartAt,
    periodEndAt,
    status,
    category,
    allCategories,
    children,
    directSpentMinor,
    directTransactions,
    spentByChild,
    errorMessage,
  ];
}
