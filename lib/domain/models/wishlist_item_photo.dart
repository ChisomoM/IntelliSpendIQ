import 'package:equatable/equatable.dart';

/// One photo attached to a [WishlistItem]. Not a synced/soft-deleted
/// entity in its own right — removing a photo removes it outright, the
/// same reasoning `TransactionLabels` uses for a join row: it has no
/// lifecycle of its own beyond existing or not.
class WishlistItemPhoto extends Equatable {
  const WishlistItemPhoto({
    required this.id,
    required this.wishlistItemId,
    required this.path,
    this.sortOrder = 0,
  });

  final String id;
  final String wishlistItemId;

  /// App-local file path, same convention as `Transaction.receiptPath`.
  final String path;

  /// Display order; the lowest also serves as the item's cover thumbnail.
  final int sortOrder;

  @override
  List<Object?> get props => [id, wishlistItemId, path, sortOrder];
}
