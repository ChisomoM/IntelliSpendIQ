part of 'categories_cubit.dart';

enum CategoriesStatus { initial, loading, loaded, invalid }

class CategoriesState extends Equatable {
  const CategoriesState({
    this.status = CategoriesStatus.initial,
    this.categories = const [],
    this.errorMessage,
  });

  final CategoriesStatus status;
  final List<Category> categories;
  final String? errorMessage;

  bool get isEmpty => status == CategoriesStatus.loaded && categories.isEmpty;

  /// Categories with no parent — the top level of the hierarchy.
  List<Category> get topLevel =>
      categories.where((c) => c.parentId == null).toList();

  /// Subcategories directly under [parentId], in the same order as
  /// [categories].
  List<Category> childrenOf(String parentId) =>
      categories.where((c) => c.parentId == parentId).toList();

  CategoriesState copyWith({
    CategoriesStatus? status,
    List<Category>? categories,
    String? errorMessage,
  }) {
    return CategoriesState(
      status: status ?? this.status,
      categories: categories ?? this.categories,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, categories, errorMessage];
}
