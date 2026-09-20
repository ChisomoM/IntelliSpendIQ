import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:intellispendiq/core/money.dart';
import 'package:intellispendiq/data/repositories/account_repository.dart';
import 'package:intellispendiq/data/repositories/category_repository.dart';
import 'package:intellispendiq/data/repositories/wishlist_repository.dart';
import 'package:intellispendiq/domain/models/account.dart';
import 'package:intellispendiq/domain/models/category.dart';
import 'package:intellispendiq/domain/models/wishlist_item.dart';
import 'package:intellispendiq/domain/models/wishlist_item_photo.dart';

part 'wishlist_item_detail_state.dart';

/// One wishlist item's photos and the three things that can happen to
/// it: turn into a [SavingsGoal], buy it (records a real expense), or
/// remove it.
class WishlistItemDetailCubit extends Cubit<WishlistItemDetailState> {
  WishlistItemDetailCubit({
    required WishlistRepository wishlist,
    required AccountRepository accounts,
    required CategoryRepository categories,
    required String itemId,
  }) : _wishlist = wishlist,
       _accounts = accounts,
       _categories = categories,
       super(WishlistItemDetailState(itemId: itemId));

  final WishlistRepository _wishlist;
  final AccountRepository _accounts;
  final CategoryRepository _categories;

  StreamSubscription<List<WishlistItem>>? _itemsSubscription;
  StreamSubscription<List<WishlistItemPhoto>>? _photosSubscription;
  StreamSubscription<List<Account>>? _accountsSubscription;

  void loadUnawaited() => unawaited(load());

  Future<void> load() async {
    emit(state.copyWith(status: WishlistItemDetailStatus.loading));
    await _itemsSubscription?.cancel();
    await _photosSubscription?.cancel();
    await _accountsSubscription?.cancel();

    emit(state.copyWith(categories: await _categories.getAll()));

    _itemsSubscription = _wishlist.watchAll().listen(_onItems);
    _photosSubscription = _wishlist.watchPhotos(state.itemId).listen(
      (photos) => emit(state.copyWith(photos: photos)),
    );
    _accountsSubscription = _accounts.watchAll().listen(
      (accounts) => emit(state.copyWith(accounts: accounts)),
    );
  }

  void _onItems(List<WishlistItem> items) {
    final item = items.where((i) => i.id == state.itemId).firstOrNull;
    if (item == null) {
      emit(state.copyWith(status: WishlistItemDetailStatus.notFound));
      return;
    }
    emit(state.copyWith(status: WishlistItemDetailStatus.loaded, item: item));
  }

  Future<void> addPhoto(String sourcePath) =>
      _wishlist.addPhoto(state.itemId, sourcePath);

  Future<void> removePhoto(String photoId) => _wishlist.removePhoto(photoId);

  Future<void> convertToGoal({
    required String targetAmount,
    DateTime? targetDate,
    String? defaultAccountId,
  }) async {
    final targetMinor = Money.tryParseToMinor(targetAmount);
    if (targetMinor == null || targetMinor <= 0) {
      emit(
        state.copyWith(
          status: WishlistItemDetailStatus.invalid,
          errorMessage: 'Enter a target amount like 1500.00',
        ),
      );
      return;
    }
    await _wishlist.convertToGoal(
      state.itemId,
      targetMinor: targetMinor,
      targetDate: targetDate,
      defaultAccountId: defaultAccountId,
    );
    emit(state.copyWith(status: WishlistItemDetailStatus.loaded));
  }

  Future<void> convertToExpense({
    required String accountId,
    required String amount,
    required DateTime transactedAt,
    String? categoryId,
  }) async {
    final amountMinor = Money.tryParseToMinor(amount);
    if (amountMinor == null || amountMinor <= 0) {
      emit(
        state.copyWith(
          status: WishlistItemDetailStatus.invalid,
          errorMessage: 'Enter a price like 1350.00',
        ),
      );
      return;
    }
    await _wishlist.convertToExpense(
      state.itemId,
      accountId: accountId,
      amountMinor: amountMinor,
      transactedAt: transactedAt,
      categoryId: categoryId,
    );
    emit(state.copyWith(status: WishlistItemDetailStatus.loaded));
  }

  Future<void> delete() => _wishlist.delete(state.itemId);

  @override
  Future<void> close() async {
    await _itemsSubscription?.cancel();
    await _photosSubscription?.cancel();
    await _accountsSubscription?.cancel();
    return super.close();
  }
}
