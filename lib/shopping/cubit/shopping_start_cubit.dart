import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:intellispendiq/core/money.dart';
import 'package:intellispendiq/core/time.dart';
import 'package:intellispendiq/data/repositories/budget_period_repository.dart';
import 'package:intellispendiq/data/repositories/category_repository.dart';
import 'package:intellispendiq/data/repositories/shopping_trip_repository.dart';
import 'package:intellispendiq/data/repositories/transaction_repository.dart';
import 'package:intellispendiq/data/repositories/wishlist_repository.dart';
import 'package:intellispendiq/domain/models/budget_period.dart';
import 'package:intellispendiq/domain/models/category.dart';
import 'package:intellispendiq/domain/models/enums.dart';
import 'package:intellispendiq/domain/models/shopping_trip.dart';
import 'package:intellispendiq/domain/models/transaction.dart';
import 'package:intellispendiq/domain/models/wishlist_item.dart';
import 'package:intellispendiq/domain/services/category_envelope_service.dart';
import 'package:intellispendiq/domain/services/shopping_trip_calculator.dart';

part 'shopping_start_state.dart';

/// "What are you buying today?": picks planned expenses and wishlist
/// items for a new trip and shows the budget they add up to.
class ShoppingStartCubit extends Cubit<ShoppingStartState> {
  ShoppingStartCubit({
    required ShoppingTripRepository trips,
    required TransactionRepository transactions,
    required WishlistRepository wishlist,
    required CategoryRepository categories,
    required BudgetPeriodRepository budgetPeriods,
    required CategoryEnvelopeService envelopes,
  }) : _trips = trips,
       _transactions = transactions,
       _wishlist = wishlist,
       _categories = categories,
       _budgetPeriods = budgetPeriods,
       _envelopes = envelopes,
       super(const ShoppingStartState());

  final ShoppingTripRepository _trips;
  final TransactionRepository _transactions;
  final WishlistRepository _wishlist;
  final CategoryRepository _categories;
  final BudgetPeriodRepository _budgetPeriods;
  final CategoryEnvelopeService _envelopes;

  StreamSubscription<List<Transaction>>? _plannedSubscription;
  StreamSubscription<List<WishlistItem>>? _wishlistSubscription;
  BudgetPeriod? _period;

  void loadUnawaited() => unawaited(load());

  Future<void> load() async {
    emit(state.copyWith(status: ShoppingStartStatus.loading));
    final period = await _budgetPeriods.ensurePeriodContaining(DateTime.now());
    _period = period;
    final categories = await _categories.getAll();
    final envelopes = await _envelopes.forPeriod(period);
    if (isClosed) return;
    emit(
      state.copyWith(
        categoriesById: {for (final c in categories) c.id: c},
        envelopes: envelopes,
      ),
    );

    await _plannedSubscription?.cancel();
    _plannedSubscription = _transactions
        .watchByStatus(TxStatus.planned)
        .listen(_onPlanned);
    await _wishlistSubscription?.cancel();
    _wishlistSubscription = _wishlist.watchAll().listen(_onWishlist);
  }

  void _onPlanned(List<Transaction> all) {
    final period = _period;
    if (period == null) return;
    final end = Iso.toDateTime(period.endAt);
    // This period's planned spending plus anything overdue; what is
    // planned for a later period is not part of today's shop.
    final due = all
        .where(
          (tx) =>
              tx.direction == TxDirection.debit &&
              tx.transactedAt.isBefore(end),
        )
        .toList();
    final ids = due.map((tx) => tx.id).toSet();
    emit(
      state.copyWith(
        status: ShoppingStartStatus.loaded,
        planned: due,
        selectedTransactionIds: state.selectedTransactionIds.intersection(ids),
      ),
    );
  }

  void _onWishlist(List<WishlistItem> all) {
    final open = all.where((i) => i.purchasedAt == null).toList();
    final ids = open.map((i) => i.id).toSet();
    emit(
      state.copyWith(
        wishlist: open,
        wishlistChoices: {
          for (final entry in state.wishlistChoices.entries)
            if (ids.contains(entry.key)) entry.key: entry.value,
        },
      ),
    );
  }

  void toggleTransaction(String id) {
    final selected = {...state.selectedTransactionIds};
    if (!selected.remove(id)) selected.add(id);
    emit(state.copyWith(selectedTransactionIds: selected));
  }

  /// Ticks every planned item in a category, or clears them all when
  /// they are already all ticked.
  void toggleCategory(String? categoryId) {
    final ids = state.plannedByCategory[categoryId]?.map((tx) => tx.id) ?? [];
    final selected = {...state.selectedTransactionIds};
    if (ids.every(selected.contains)) {
      selected.removeAll(ids);
    } else {
      selected.addAll(ids);
    }
    emit(state.copyWith(selectedTransactionIds: selected));
  }

  void toggleAll() {
    final all = state.planned.map((tx) => tx.id).toSet();
    final everything = state.selectedTransactionIds.length == all.length;
    emit(
      state.copyWith(selectedTransactionIds: everything ? <String>{} : all),
    );
  }

  void toggleWishlist(String id) {
    final choices = {...state.wishlistChoices};
    if (choices.remove(id) == null) choices[id] = const WishlistChoice();
    emit(state.copyWith(wishlistChoices: choices));
  }

  void setWishlistCategory(String id, String? categoryId) {
    final current = state.wishlistChoices[id] ?? const WishlistChoice();
    emit(
      state.copyWith(
        wishlistChoices: {
          ...state.wishlistChoices,
          id: WishlistChoice(
            categoryId: categoryId,
            priceMinor: current.priceMinor,
          ),
        },
      ),
    );
  }

  /// Returns an error message for the field, or null when accepted.
  String? setWishlistPrice(String id, String price) {
    final cents = Money.tryParseToMinor(price);
    if (cents == null || cents <= 0) return 'Enter a price like 25.50';
    final current = state.wishlistChoices[id] ?? const WishlistChoice();
    emit(
      state.copyWith(
        wishlistChoices: {
          ...state.wishlistChoices,
          id: WishlistChoice(
            categoryId: current.categoryId,
            priceMinor: cents,
          ),
        },
      ),
    );
    return null;
  }

  Future<void> start() async {
    if (!state.canStart) return;
    emit(state.copyWith(status: ShoppingStartStatus.starting));
    try {
      await _trips.startTrip(
        plannedTransactionIds: state.selectedTransactionIds.toList(),
        wishlistPicks: [
          for (final entry in state.wishlistChoices.entries)
            WishlistPick(
              wishlistItemId: entry.key,
              categoryId: entry.value.categoryId,
              priceMinor: entry.value.priceMinor,
            ),
        ],
      );
      emit(state.copyWith(status: ShoppingStartStatus.started));
    } on Object catch (error) {
      emit(
        state.copyWith(
          status: ShoppingStartStatus.failed,
          errorMessage: "Couldn't start the trip: $error",
        ),
      );
    }
  }

  @override
  Future<void> close() async {
    await _plannedSubscription?.cancel();
    await _wishlistSubscription?.cancel();
    return super.close();
  }
}
