part of 'shopping_start_cubit.dart';

enum ShoppingStartStatus { initial, loading, loaded, starting, started, failed }

/// A wishlist item ticked for the trip, with the category and price it
/// will be bought under.
class WishlistChoice extends Equatable {
  const WishlistChoice({this.categoryId, this.priceMinor});

  final String? categoryId;
  final int? priceMinor;

  @override
  List<Object?> get props => [categoryId, priceMinor];
}

class ShoppingStartState extends Equatable {
  const ShoppingStartState({
    this.status = ShoppingStartStatus.initial,
    this.planned = const [],
    this.wishlist = const [],
    this.categoriesById = const {},
    this.envelopes = const {},
    this.selectedTransactionIds = const {},
    this.wishlistChoices = const {},
    this.errorMessage,
  });

  final ShoppingStartStatus status;

  /// Unpaid planned expenses due this period or earlier.
  final List<Transaction> planned;

  /// Wishlist items not yet bought.
  final List<WishlistItem> wishlist;
  final Map<String, Category> categoriesById;
  final Map<String, CategoryEnvelope> envelopes;
  final Set<String> selectedTransactionIds;
  final Map<String, WishlistChoice> wishlistChoices;
  final String? errorMessage;

  bool get isLoaded =>
      status != ShoppingStartStatus.initial &&
      status != ShoppingStartStatus.loading;

  int get selectedCount =>
      selectedTransactionIds.length + wishlistChoices.length;

  bool get canStart =>
      selectedCount > 0 && status == ShoppingStartStatus.loaded;

  /// The top-level category a planned expense counts against.
  String? topLevelOf(String? categoryId) => ShoppingTripCalculator.topLevelId(
    categoryId,
    categoriesById,
  );

  /// Planned expenses grouped by top-level category, in the order the
  /// categories first appear.
  Map<String?, List<Transaction>> get plannedByCategory {
    final groups = <String?, List<Transaction>>{};
    for (final tx in planned) {
      (groups[topLevelOf(tx.categoryId)] ??= []).add(tx);
    }
    return groups;
  }

  /// What the trip would look like if started now, for the live budget
  /// line at the bottom of the screen.
  TripSummary get preview {
    final items = <ShoppingTripItem>[];
    for (final tx in planned) {
      if (!selectedTransactionIds.contains(tx.id)) continue;
      items.add(
        ShoppingTripItem(
          id: tx.id,
          tripId: '',
          kind: ShoppingItemKind.planned,
          name: tx.merchant ?? '',
          categoryId: tx.categoryId,
          unitPriceMinor: tx.amountMinor,
        ),
      );
    }
    for (final item in wishlist) {
      final choice = wishlistChoices[item.id];
      if (choice == null) continue;
      items.add(
        ShoppingTripItem(
          id: item.id,
          tripId: '',
          kind: ShoppingItemKind.wishlist,
          name: item.name,
          categoryId: choice.categoryId,
          unitPriceMinor: choice.priceMinor ?? item.estimatedPriceMinor ?? 0,
        ),
      );
    }
    return ShoppingTripCalculator.summarize(
      items: items,
      envelopes: envelopes,
      categoriesById: categoriesById,
    );
  }

  ShoppingStartState copyWith({
    ShoppingStartStatus? status,
    List<Transaction>? planned,
    List<WishlistItem>? wishlist,
    Map<String, Category>? categoriesById,
    Map<String, CategoryEnvelope>? envelopes,
    Set<String>? selectedTransactionIds,
    Map<String, WishlistChoice>? wishlistChoices,
    String? errorMessage,
  }) {
    return ShoppingStartState(
      status: status ?? this.status,
      planned: planned ?? this.planned,
      wishlist: wishlist ?? this.wishlist,
      categoriesById: categoriesById ?? this.categoriesById,
      envelopes: envelopes ?? this.envelopes,
      selectedTransactionIds:
          selectedTransactionIds ?? this.selectedTransactionIds,
      wishlistChoices: wishlistChoices ?? this.wishlistChoices,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [
    status,
    planned,
    wishlist,
    categoriesById,
    envelopes,
    selectedTransactionIds,
    wishlistChoices,
    errorMessage,
  ];
}
