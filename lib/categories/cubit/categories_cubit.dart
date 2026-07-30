import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:intellispendiq/data/repositories/category_repository.dart';
import 'package:intellispendiq/domain/models/category.dart';

part 'categories_state.dart';

/// Lets the user add, rename, and remove spending categories beyond
/// the ten seeded on first launch.
class CategoriesCubit extends Cubit<CategoriesState> {
  CategoriesCubit(this._categories) : super(const CategoriesState());

  final CategoryRepository _categories;
  StreamSubscription<List<Category>>? _subscription;

  void loadUnawaited() => unawaited(load());

  Future<void> load() async {
    emit(state.copyWith(status: CategoriesStatus.loading));
    await _subscription?.cancel();
    _subscription = _categories.watchAll().listen(
      (rows) => emit(
        state.copyWith(status: CategoriesStatus.loaded, categories: rows),
      ),
    );
  }

  Future<void> add({required String name, String? icon}) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      emit(
        state.copyWith(
          status: CategoriesStatus.invalid,
          errorMessage: 'Give the category a name',
        ),
      );
      return;
    }
    await _categories.create(trimmed, icon: _trimIcon(icon));
  }

  Future<void> rename(
    String id, {
    required String name,
    String? icon,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      emit(
        state.copyWith(
          status: CategoriesStatus.invalid,
          errorMessage: 'Give the category a name',
        ),
      );
      return;
    }
    final trimmedIcon = _trimIcon(icon);
    await _categories.update(
      id,
      name: trimmed,
      icon: trimmedIcon,
      clearIcon: trimmedIcon == null,
    );
  }

  Future<void> delete(String id) async {
    final removed = await _categories.delete(id);
    if (!removed) {
      emit(
        state.copyWith(
          status: CategoriesStatus.invalid,
          errorMessage: "Default categories can't be deleted",
        ),
      );
    }
  }

  String? _trimIcon(String? icon) {
    final trimmed = icon?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}
