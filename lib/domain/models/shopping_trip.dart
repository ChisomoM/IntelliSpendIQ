import 'package:equatable/equatable.dart';

enum ShoppingTripStatus {
  active,
  completed,
  cancelled;

  static ShoppingTripStatus fromDbName(String name) =>
      values.firstWhere((s) => s.name == name);
}

/// Where a [ShoppingTripItem] came from. Impulse is simply "was not on
/// the list": there is no separate flag to keep in sync.
enum ShoppingItemKind {
  /// An existing planned expense, flipped to confirmed at checkout.
  planned,

  /// A wishlist item, bought as a new expense at checkout.
  wishlist,

  /// Added in the shop, never planned. Becomes a new expense.
  impulse;

  static ShoppingItemKind fromDbName(String name) =>
      values.firstWhere((k) => k.name == name);
}

/// A focused buying session. See `ShoppingTrips` for why planned
/// transactions stay untouched until checkout.
class ShoppingTrip extends Equatable {
  const ShoppingTrip({
    required this.id,
    required this.periodId,
    required this.status,
    required this.startedAt,
    this.finishedAt,
  });

  final String id;
  final String periodId;
  final ShoppingTripStatus status;
  final DateTime startedAt;
  final DateTime? finishedAt;

  bool get isActive => status == ShoppingTripStatus.active;

  @override
  List<Object?> get props => [id, periodId, status, startedAt, finishedAt];
}

class ShoppingTripItem extends Equatable {
  const ShoppingTripItem({
    required this.id,
    required this.tripId,
    required this.kind,
    required this.name,
    required this.unitPriceMinor,
    this.transactionId,
    this.wishlistItemId,
    this.categoryId,
    this.plannedPriceMinor,
    this.quantity = 1,
    this.inCart = false,
    this.sortOrder = 0,
  });

  final String id;
  final String tripId;
  final ShoppingItemKind kind;
  final String? transactionId;
  final String? wishlistItemId;
  final String name;
  final String? categoryId;
  final int? plannedPriceMinor;
  final int unitPriceMinor;
  final int quantity;
  final bool inCart;
  final int sortOrder;

  bool get isImpulse => kind == ShoppingItemKind.impulse;
  bool get isPlanned => !isImpulse;

  /// Unit price times quantity, in ngwee: what this line costs.
  int get lineTotalMinor => unitPriceMinor * quantity;

  ShoppingTripItem copyWith({
    String? name,
    String? categoryId,
    bool clearCategory = false,
    int? unitPriceMinor,
    int? quantity,
    bool? inCart,
  }) => ShoppingTripItem(
    id: id,
    tripId: tripId,
    kind: kind,
    transactionId: transactionId,
    wishlistItemId: wishlistItemId,
    name: name ?? this.name,
    categoryId: clearCategory ? null : (categoryId ?? this.categoryId),
    plannedPriceMinor: plannedPriceMinor,
    unitPriceMinor: unitPriceMinor ?? this.unitPriceMinor,
    quantity: quantity ?? this.quantity,
    inCart: inCart ?? this.inCart,
    sortOrder: sortOrder,
  );

  @override
  List<Object?> get props => [
    id,
    tripId,
    kind,
    transactionId,
    wishlistItemId,
    name,
    categoryId,
    plannedPriceMinor,
    unitPriceMinor,
    quantity,
    inCart,
    sortOrder,
  ];
}
