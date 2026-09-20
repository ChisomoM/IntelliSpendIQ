part of 'wishlist_item_detail_cubit.dart';

enum WishlistItemDetailStatus { initial, loading, loaded, invalid, notFound }

class WishlistItemDetailState extends Equatable {
  const WishlistItemDetailState({
    required this.itemId,
    this.status = WishlistItemDetailStatus.initial,
    this.item,
    this.photos = const [],
    this.accounts = const [],
    this.categories = const [],
    this.errorMessage,
  });

  final String itemId;
  final WishlistItemDetailStatus status;
  final WishlistItem? item;
  final List<WishlistItemPhoto> photos;
  final List<Account> accounts;
  final List<Category> categories;
  final String? errorMessage;

  WishlistItemDetailState copyWith({
    WishlistItemDetailStatus? status,
    WishlistItem? item,
    List<WishlistItemPhoto>? photos,
    List<Account>? accounts,
    List<Category>? categories,
    String? errorMessage,
  }) {
    return WishlistItemDetailState(
      itemId: itemId,
      status: status ?? this.status,
      item: item ?? this.item,
      photos: photos ?? this.photos,
      accounts: accounts ?? this.accounts,
      categories: categories ?? this.categories,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [
    itemId,
    status,
    item,
    photos,
    accounts,
    categories,
    errorMessage,
  ];
}
