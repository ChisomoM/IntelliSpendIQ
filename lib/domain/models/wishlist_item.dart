import 'package:equatable/equatable.dart';

/// Where a [WishlistItem] sits in its lifecycle — derived from its own
/// pointers rather than stored as its own column, so it can never drift
/// out of sync with what actually happened to the item.
enum WishlistItemStatus {
  /// Nothing committed yet — not funded, not bought.
  idea,

  /// Converted into a [SavingsGoal]; still not bought.
  saving,

  /// Converted into a real expense.
  purchased,
}

/// Something the user wants but hasn't committed to yet — no budget, no
/// savings goal, no money moved. Deliberately pre-financial: it never
/// appears in a balance, budget, or report until it's converted into a
/// [SavingsGoal] or a real expense [Transaction].
class WishlistItem extends Equatable {
  const WishlistItem({
    required this.id,
    required this.name,
    this.estimatedPriceMinor,
    this.actualPriceMinor,
    this.seenAt,
    this.productUrl,
    this.note,
    this.linkedGoalId,
    this.linkedTransactionId,
    this.purchasedAt,
  });

  final String id;
  final String name;

  /// What the user thinks it costs, in ngwee. Optional — capturing the
  /// idea shouldn't require knowing the price yet.
  final int? estimatedPriceMinor;

  /// What was actually paid, set when [purchasedAt] is set.
  final int? actualPriceMinor;

  /// Free text: where the user saw it (a shop, a site, a friend's house).
  final String? seenAt;
  final String? productUrl;
  final String? note;

  /// The [SavingsGoal] this item was converted into, if any.
  final String? linkedGoalId;

  /// The expense [Transaction] this item was bought as, if any.
  final String? linkedTransactionId;

  /// Non-null once the item has been bought.
  final DateTime? purchasedAt;

  WishlistItemStatus get status {
    if (purchasedAt != null) return WishlistItemStatus.purchased;
    if (linkedGoalId != null) return WishlistItemStatus.saving;
    return WishlistItemStatus.idea;
  }

  @override
  List<Object?> get props => [
    id,
    name,
    estimatedPriceMinor,
    actualPriceMinor,
    seenAt,
    productUrl,
    note,
    linkedGoalId,
    linkedTransactionId,
    purchasedAt,
  ];
}
