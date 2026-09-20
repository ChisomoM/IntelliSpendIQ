import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:intellispendiq/core/money.dart';
import 'package:intellispendiq/data/repositories/wishlist_repository.dart';
import 'package:intellispendiq/domain/models/wishlist_item.dart';

part 'wishlist_state.dart';

/// Every wishlist item — things the user wants but hasn't committed to
/// yet. Never touches a balance, budget, or report; see [WishlistItem].
class WishlistCubit extends Cubit<WishlistState> {
  WishlistCubit(this._wishlist) : super(const WishlistState());

  final WishlistRepository _wishlist;
  StreamSubscription<List<WishlistItem>>? _subscription;
  StreamSubscription<Map<String, String>>? _coversSubscription;

  void loadUnawaited() => unawaited(load());

  Future<void> load() async {
    emit(state.copyWith(status: WishlistStatus.loading));
    await _subscription?.cancel();
    await _coversSubscription?.cancel();
    _subscription = _wishlist.watchAll().listen(
      (items) =>
          emit(state.copyWith(status: WishlistStatus.loaded, items: items)),
    );
    _coversSubscription = _wishlist.watchCovers().listen(
      (covers) => emit(state.copyWith(covers: covers)),
    );
  }

  void filterChanged(WishlistFilter filter) =>
      emit(state.copyWith(filter: filter));

  Future<void> create({
    required String name,
    String estimatedPrice = '',
    String? seenAt,
    String? productUrl,
    String? note,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      emit(
        state.copyWith(
          status: WishlistStatus.invalid,
          errorMessage: 'Give it a name',
        ),
      );
      return;
    }

    int? estimatedPriceMinor;
    final trimmedPrice = estimatedPrice.trim();
    if (trimmedPrice.isNotEmpty) {
      estimatedPriceMinor = Money.tryParseToMinor(trimmedPrice);
      if (estimatedPriceMinor == null || estimatedPriceMinor < 0) {
        emit(
          state.copyWith(
            status: WishlistStatus.invalid,
            errorMessage: 'Enter a price like 1500.00, or leave it blank',
          ),
        );
        return;
      }
    }

    await _wishlist.create(
      name: trimmed,
      estimatedPriceMinor: estimatedPriceMinor,
      seenAt: (seenAt == null || seenAt.trim().isEmpty) ? null : seenAt.trim(),
      productUrl: (productUrl == null || productUrl.trim().isEmpty)
          ? null
          : productUrl.trim(),
      note: (note == null || note.trim().isEmpty) ? null : note.trim(),
    );
    emit(state.copyWith(status: WishlistStatus.loaded));
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    await _coversSubscription?.cancel();
    return super.close();
  }
}
