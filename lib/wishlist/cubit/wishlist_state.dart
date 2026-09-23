part of 'wishlist_cubit.dart';

enum WishlistStatus { initial, loading, loaded, invalid }

/// Matches [WishlistItemStatus], plus `all` for the unfiltered list.
enum WishlistFilter { all, idea, saving, purchased }

class WishlistState extends Equatable {
  const WishlistState({
    this.status = WishlistStatus.initial,
    this.items = const [],
    this.covers = const {},
    this.filter = WishlistFilter.all,
    this.errorMessage,
  });

  final WishlistStatus status;
  final List<WishlistItem> items;

  /// Each item's lowest-sort-order photo path, keyed by item id — see
  /// `WishlistRepository.watchCovers`. An id missing here means the item
  /// has no photos yet.
  final Map<String, String> covers;
  final WishlistFilter filter;
  final String? errorMessage;

  bool get isEmpty => status == WishlistStatus.loaded && items.isEmpty;

  List<WishlistItem> get filtered {
    if (filter == WishlistFilter.all) return items;
    final target = switch (filter) {
      WishlistFilter.idea => WishlistItemStatus.idea,
      WishlistFilter.saving => WishlistItemStatus.saving,
      WishlistFilter.purchased => WishlistItemStatus.purchased,
      WishlistFilter.all => throw StateError('unreachable'),
    };
    return items.where((item) => item.status == target).toList();
  }

  List<WishlistItem> _withStatus(WishlistItemStatus target) =>
      items.where((item) => item.status == target).toList();

  List<WishlistItem> get ideaItems => _withStatus(WishlistItemStatus.idea);
  List<WishlistItem> get savingItems => _withStatus(WishlistItemStatus.saving);
  List<WishlistItem> get purchasedItems =>
      _withStatus(WishlistItemStatus.purchased);

  /// What's still outstanding: the estimated cost of everything not yet
  /// bought. Purchased items are excluded — once bought, their cost is
  /// real spend recorded on a transaction elsewhere, not an aspiration.
  int get outstandingTotalMinor => [...ideaItems, ...savingItems].fold(
    0,
    (sum, item) => sum + (item.estimatedPriceMinor ?? 0),
  );

  int get ideaTotalMinor => ideaItems.fold(
    0,
    (sum, item) => sum + (item.estimatedPriceMinor ?? 0),
  );

  int get savingTotalMinor => savingItems.fold(
    0,
    (sum, item) => sum + (item.estimatedPriceMinor ?? 0),
  );

  /// What was actually paid for purchased items — falls back to the
  /// estimate only for the rare item marked purchased without ever
  /// recording a price.
  int get purchasedTotalMinor => purchasedItems.fold(
    0,
    (sum, item) =>
        sum + (item.actualPriceMinor ?? item.estimatedPriceMinor ?? 0),
  );

  WishlistState copyWith({
    WishlistStatus? status,
    List<WishlistItem>? items,
    Map<String, String>? covers,
    WishlistFilter? filter,
    String? errorMessage,
  }) {
    return WishlistState(
      status: status ?? this.status,
      items: items ?? this.items,
      covers: covers ?? this.covers,
      filter: filter ?? this.filter,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, items, covers, filter, errorMessage];
}
