part of 'shopping_trip_cubit.dart';

enum ShoppingTripViewStatus {
  initial,

  /// No active trip: show the start screen.
  none,
  active,
  checkingOut,

  /// Checkout finished; [ShoppingTripState.result] holds the outcome.
  done,
}

/// A one-off warning for the page to surface: a category just crossed
/// into "nearing" or "over". [seq] makes two identical warnings in a
/// row distinct, so a listener fires for each.
class TripAlert extends Equatable {
  const TripAlert({
    required this.seq,
    required this.categoryId,
    required this.severity,
    required this.leftMinor,
  });

  final int seq;
  final String? categoryId;
  final TripSeverity severity;

  /// Room left in the category (negative when over).
  final int leftMinor;

  @override
  List<Object?> get props => [seq, categoryId, severity, leftMinor];
}

class ShoppingTripState extends Equatable {
  const ShoppingTripState({
    this.status = ShoppingTripViewStatus.initial,
    this.trip,
    this.items = const [],
    this.categoriesById = const {},
    this.envelopes = const {},
    this.summary = TripSummary.empty,
    this.accounts = const [],
    this.categoryFilter,
    this.alert,
    this.result,
    this.errorMessage,
  });

  /// Stands in for "items without a category" in [categoryFilter].
  static const noCategoryKey = '_none';

  final ShoppingTripViewStatus status;
  final ShoppingTrip? trip;
  final List<ShoppingTripItem> items;
  final Map<String, Category> categoriesById;
  final Map<String, CategoryEnvelope> envelopes;
  final TripSummary summary;
  final List<Account> accounts;

  /// Top-level category the list is narrowed to, or null for all.
  final String? categoryFilter;
  final TripAlert? alert;
  final CheckoutResult? result;
  final String? errorMessage;

  bool get hasTrip => trip != null;

  String? _keyOf(ShoppingTripItem item) {
    final id = ShoppingTripCalculator.topLevelId(
      item.categoryId,
      categoriesById,
    );
    return id ?? noCategoryKey;
  }

  bool _visible(ShoppingTripItem item) =>
      categoryFilter == null || _keyOf(item) == categoryFilter;

  /// Planned and wishlist lines still to be picked up.
  List<ShoppingTripItem> get toBuy =>
      items.where((i) => i.isPlanned && !i.inCart && _visible(i)).toList();

  List<ShoppingTripItem> get inCart =>
      items.where((i) => i.inCart && _visible(i)).toList();

  int get cartCount => items.where((i) => i.inCart).length;

  /// Name for a top-level category key, as the trip's lines show it.
  String categoryName(String? categoryId) {
    if (categoryId == null) return 'No category';
    return categoriesById[categoryId]?.name ?? 'No category';
  }

  ShoppingTripState copyWith({
    ShoppingTripViewStatus? status,
    ShoppingTrip? trip,
    bool clearTrip = false,
    List<ShoppingTripItem>? items,
    Map<String, Category>? categoriesById,
    Map<String, CategoryEnvelope>? envelopes,
    TripSummary? summary,
    List<Account>? accounts,
    String? categoryFilter,
    bool clearFilter = false,
    TripAlert? alert,
    CheckoutResult? result,
    String? errorMessage,
  }) {
    return ShoppingTripState(
      status: status ?? this.status,
      trip: clearTrip ? null : (trip ?? this.trip),
      items: items ?? this.items,
      categoriesById: categoriesById ?? this.categoriesById,
      envelopes: envelopes ?? this.envelopes,
      summary: summary ?? this.summary,
      accounts: accounts ?? this.accounts,
      categoryFilter: clearFilter
          ? null
          : (categoryFilter ?? this.categoryFilter),
      alert: alert,
      result: result ?? this.result,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [
    status,
    trip,
    items,
    categoriesById,
    envelopes,
    summary,
    accounts,
    categoryFilter,
    alert,
    result,
    errorMessage,
  ];
}
