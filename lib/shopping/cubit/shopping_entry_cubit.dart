import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:intellispendiq/data/repositories/shopping_trip_repository.dart';
import 'package:intellispendiq/domain/models/shopping_trip.dart';

/// What Home needs to know about the trip in progress: whether there
/// is one and what is in the cart. The full numbers live on the trip
/// screen.
class ShoppingEntryState extends Equatable {
  const ShoppingEntryState({
    this.hasActiveTrip = false,
    this.cartTotalMinor = 0,
    this.cartCount = 0,
  });

  final bool hasActiveTrip;
  final int cartTotalMinor;
  final int cartCount;

  @override
  List<Object?> get props => [hasActiveTrip, cartTotalMinor, cartCount];
}

class ShoppingEntryCubit extends Cubit<ShoppingEntryState> {
  ShoppingEntryCubit(this._trips) : super(const ShoppingEntryState());

  final ShoppingTripRepository _trips;
  StreamSubscription<ShoppingTrip?>? _tripSubscription;
  StreamSubscription<List<ShoppingTripItem>>? _itemsSubscription;

  void loadUnawaited() => unawaited(load());

  Future<void> load() async {
    await _tripSubscription?.cancel();
    _tripSubscription = _trips.watchActive().listen((trip) async {
      await _itemsSubscription?.cancel();
      if (trip == null) {
        emit(const ShoppingEntryState());
        return;
      }
      emit(const ShoppingEntryState(hasActiveTrip: true));
      _itemsSubscription = _trips.watchItems(trip.id).listen((items) {
        final cart = items.where((i) => i.inCart);
        emit(
          ShoppingEntryState(
            hasActiveTrip: true,
            cartTotalMinor: cart.fold(0, (sum, i) => sum + i.lineTotalMinor),
            cartCount: cart.length,
          ),
        );
      });
    });
  }

  @override
  Future<void> close() async {
    await _tripSubscription?.cancel();
    await _itemsSubscription?.cancel();
    return super.close();
  }
}
