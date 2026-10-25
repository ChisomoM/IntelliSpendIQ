import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:intellispendiq/core/money.dart';
import 'package:intellispendiq/data/repositories/account_repository.dart';
import 'package:intellispendiq/data/repositories/budget_period_repository.dart';
import 'package:intellispendiq/data/repositories/category_repository.dart';
import 'package:intellispendiq/data/repositories/shopping_trip_repository.dart';
import 'package:intellispendiq/domain/models/account.dart';
import 'package:intellispendiq/domain/models/budget_period.dart';
import 'package:intellispendiq/domain/models/category.dart';
import 'package:intellispendiq/domain/models/shopping_trip.dart';
import 'package:intellispendiq/domain/services/category_envelope_service.dart';
import 'package:intellispendiq/domain/services/shopping_trip_calculator.dart';

part 'shopping_trip_state.dart';

/// The live trip: its cart, the per-category numbers, and the checkout.
class ShoppingTripCubit extends Cubit<ShoppingTripState> {
  ShoppingTripCubit({
    required ShoppingTripRepository trips,
    required CategoryRepository categories,
    required BudgetPeriodRepository budgetPeriods,
    required CategoryEnvelopeService envelopes,
    required AccountRepository accounts,
  }) : _trips = trips,
       _categories = categories,
       _budgetPeriods = budgetPeriods,
       _envelopes = envelopes,
       _accounts = accounts,
       super(const ShoppingTripState());

  final ShoppingTripRepository _trips;
  final CategoryRepository _categories;
  final BudgetPeriodRepository _budgetPeriods;
  final CategoryEnvelopeService _envelopes;
  final AccountRepository _accounts;

  StreamSubscription<ShoppingTrip?>? _tripSubscription;
  StreamSubscription<List<ShoppingTripItem>>? _itemsSubscription;
  BudgetPeriod? _period;
  int _alertSeq = 0;

  /// Whether the first load has been absorbed. A trip that is resumed
  /// already past a line should not announce it again.
  bool _primed = false;

  /// The worst severity already announced per category, so a warning
  /// fires when a category crosses a line and not on every edit after.
  final Map<String?, TripSeverity> _announced = {};

  void loadUnawaited() => unawaited(load());

  Future<void> load() async {
    await _tripSubscription?.cancel();
    _tripSubscription = _trips.watchActive().listen(_onTrip);
  }

  Future<void> _onTrip(ShoppingTrip? trip) async {
    await _itemsSubscription?.cancel();
    if (trip == null) {
      // A finished trip keeps its result on screen instead of falling
      // back to the start screen.
      if (state.status == ShoppingTripViewStatus.checkingOut ||
          state.status == ShoppingTripViewStatus.done) {
        return;
      }
      emit(
        state.copyWith(
          status: ShoppingTripViewStatus.none,
          clearTrip: true,
          items: const [],
          summary: TripSummary.empty,
        ),
      );
      return;
    }
    if (_period?.id != trip.periodId) {
      _period = await _budgetPeriods.getPeriod(trip.periodId);
    }
    final categories = await _categories.getAll();
    final accounts = await _accounts.getAll();
    if (isClosed) return;
    emit(
      state.copyWith(
        trip: trip,
        categoriesById: {for (final c in categories) c.id: c},
        accounts: accounts,
      ),
    );
    _itemsSubscription = _trips.watchItems(trip.id).listen(_onItems);
  }

  /// Reloads the category list, after one was added from the picker.
  Future<void> refreshCategories() async {
    final categories = await _categories.getAll();
    if (isClosed) return;
    emit(state.copyWith(categoriesById: {for (final c in categories) c.id: c}));
    await _onItems(state.items);
  }

  Future<void> _onItems(List<ShoppingTripItem> items) async {
    final period = _period;
    if (period == null || isClosed) return;
    final envelopes = await _envelopes.forPeriod(period);
    if (isClosed) return;
    final summary = ShoppingTripCalculator.summarize(
      items: items,
      envelopes: envelopes,
      categoriesById: state.categoriesById,
    );
    var alert = _nextAlert(summary);
    if (!_primed) {
      _primed = true;
      alert = null;
    }
    if (state.status == ShoppingTripViewStatus.checkingOut ||
        state.status == ShoppingTripViewStatus.done) {
      return;
    }
    emit(
      state.copyWith(
        status: ShoppingTripViewStatus.active,
        items: items,
        envelopes: envelopes,
        summary: summary,
        alert: alert,
      ),
    );
  }

  TripAlert? _nextAlert(TripSummary summary) {
    TripAlert? alert;
    for (final line in summary.lines) {
      final severity = line.severity;
      final before = _announced[line.categoryId] ?? TripSeverity.ok;
      if (severity.index > before.index) {
        // The more serious alert wins when two categories cross at once.
        if (alert == null || severity.index > alert.severity.index) {
          alert = TripAlert(
            seq: ++_alertSeq,
            categoryId: line.categoryId,
            severity: severity,
            leftMinor: line.leftMinor ?? 0,
          );
        }
      }
      _announced[line.categoryId] = severity;
    }
    return alert;
  }

  // --- Cart --------------------------------------------------------------

  /// Moves a planned line into the cart, or back to "to buy". Returns
  /// false when the line has no price yet and so cannot go in the cart.
  Future<bool> toggleInCart(ShoppingTripItem item) async {
    if (!item.inCart && item.unitPriceMinor <= 0) return false;
    await _trips.updateItem(item.id, inCart: !item.inCart);
    return true;
  }

  /// Adds something that was not on the list. Returns an error message
  /// to show against the field, or null on success.
  Future<String?> addImpulse({
    required String name,
    required String price,
    int quantity = 1,
    String? categoryId,
  }) async {
    final trip = state.trip;
    if (trip == null) return 'No trip in progress';
    final cents = Money.tryParseToMinor(price);
    if (cents == null || cents <= 0) return 'Enter a price like 25.50';
    final trimmed = name.trim();
    await _trips.addImpulse(
      tripId: trip.id,
      name: trimmed.isEmpty ? 'Item' : trimmed,
      unitPriceMinor: cents,
      quantity: quantity,
      categoryId: categoryId,
    );
    return null;
  }

  Future<String?> setPrice(ShoppingTripItem item, String price) async {
    final cents = Money.tryParseToMinor(price);
    if (cents == null || cents <= 0) return 'Enter a price like 25.50';
    await _trips.updateItem(item.id, unitPriceMinor: cents);
    return null;
  }

  Future<void> setQuantity(ShoppingTripItem item, int quantity) =>
      _trips.updateItem(item.id, quantity: quantity < 1 ? 1 : quantity);

  Future<void> setName(ShoppingTripItem item, String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    await _trips.updateItem(item.id, name: trimmed);
  }

  Future<void> setCategory(ShoppingTripItem item, String? categoryId) =>
      _trips.updateItem(
        item.id,
        categoryId: categoryId,
        clearCategory: categoryId == null,
      );

  /// Takes the line out of the cart. A planned line goes back to "to
  /// buy" and an impulse line is removed; either way the returned
  /// callback undoes it.
  ///
  /// The list updates before the database write returns: a swiped-away
  /// row has to leave the tree in the same frame, or the Dismissible
  /// that produced the swipe complains.
  Future<Future<void> Function()> removeFromCart(
    ShoppingTripItem item,
  ) async {
    if (item.isPlanned) {
      emit(
        state.copyWith(
          items: [
            for (final i in state.items)
              i.id == item.id ? i.copyWith(inCart: false) : i,
          ],
        ),
      );
      await _trips.updateItem(item.id, inCart: false);
      return () => _trips.updateItem(item.id, inCart: true);
    }
    emit(
      state.copyWith(items: state.items.where((i) => i.id != item.id).toList()),
    );
    await _trips.removeItem(item.id);
    return () => _trips.restoreItem(item.id);
  }

  /// Drops a planned line from the trip altogether.
  Future<Future<void> Function()> removeFromTrip(
    ShoppingTripItem item,
  ) async {
    emit(
      state.copyWith(items: state.items.where((i) => i.id != item.id).toList()),
    );
    await _trips.removeItem(item.id);
    return () => _trips.restoreItem(item.id);
  }

  void filterChanged(String? key) => emit(
    key == null || key == state.categoryFilter
        ? state.copyWith(clearFilter: true)
        : state.copyWith(categoryFilter: key),
  );

  // --- Afford --------------------------------------------------------------

  /// "Can I afford this?" for a price, quantity and category, judged
  /// against the trip as it stands.
  AffordAnswer? canAfford({
    required String price,
    int quantity = 1,
    String? categoryId,
  }) {
    final cents = Money.tryParseToMinor(price);
    if (cents == null || cents <= 0) return null;
    return ShoppingTripCalculator.canAfford(
      items: state.items,
      envelopes: state.envelopes,
      categoriesById: state.categoriesById,
      unitPriceMinor: cents,
      quantity: quantity < 1 ? 1 : quantity,
      categoryId: categoryId,
    );
  }

  // --- Finishing -----------------------------------------------------------

  Future<void> cancelTrip() async {
    final trip = state.trip;
    if (trip == null) return;
    await _trips.cancelTrip(trip.id);
  }

  Future<void> checkout(String accountId) async {
    final trip = state.trip;
    if (trip == null) return;
    emit(state.copyWith(status: ShoppingTripViewStatus.checkingOut));
    try {
      final result = await _trips.checkout(
        tripId: trip.id,
        accountId: accountId,
      );
      emit(
        state.copyWith(status: ShoppingTripViewStatus.done, result: result),
      );
    } on Object catch (error) {
      emit(
        state.copyWith(
          status: ShoppingTripViewStatus.active,
          errorMessage: "Couldn't finish the trip: $error",
        ),
      );
    }
  }

  @override
  Future<void> close() async {
    await _tripSubscription?.cancel();
    await _itemsSubscription?.cancel();
    return super.close();
  }
}
