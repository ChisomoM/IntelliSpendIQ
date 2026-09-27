part of 'receipt_items_cubit.dart';

enum ReceiptItemsStatus { editing, saving, saved, failure }

/// One row on the review screen — an OCR-found line item, or one the
/// user added by hand. Seeded with Claude's per-item category
/// suggestion when the scan offered one (a product name like "Bread"
/// doesn't fit the merchant-keyed keyword table the SMS path uses, so
/// this is a separate, per-item suggestion) — always editable, and
/// left null when nothing was suggested, same as any other
/// uncategorized transaction.
class ReceiptItemDraft extends Equatable {
  ReceiptItemDraft({
    required this.included,
    required this.name,
    required this.amount,
    this.categoryId,
  }) : id = Ids.newId();

  ReceiptItemDraft._({
    required this.id,
    required this.included,
    required this.name,
    required this.amount,
    this.categoryId,
  });

  /// Stable across edits/reordering — a row's widget is keyed by this,
  /// not its list index, so removing one item never makes another
  /// row's text field silently show the wrong item's stale text.
  final String id;
  final bool included;
  final String name;

  /// Major-unit decimal string, e.g. `"15.00"` — matches the amount
  /// field's text representation everywhere else in the app.
  final String amount;

  final String? categoryId;

  bool get hasValidAmount {
    final minor = Money.tryParseToMinor(amount);
    return minor != null && minor > 0;
  }

  ReceiptItemDraft copyWith({
    bool? included,
    String? name,
    String? amount,
    String? categoryId,
    bool clearCategory = false,
  }) {
    return ReceiptItemDraft._(
      id: id,
      included: included ?? this.included,
      name: name ?? this.name,
      amount: amount ?? this.amount,
      categoryId: clearCategory ? null : (categoryId ?? this.categoryId),
    );
  }

  @override
  List<Object?> get props => [id, included, name, amount, categoryId];
}

class ReceiptItemsState extends Equatable {
  const ReceiptItemsState({
    required this.merchant,
    required this.transactedAt,
    required this.items,
    required this.sourcePath,
    this.status = ReceiptItemsStatus.editing,
    this.accountId,
    this.accounts = const [],
    this.categories = const [],
    this.errorMessage,
  });

  final String merchant;
  final DateTime transactedAt;
  final List<ReceiptItemDraft> items;

  /// Wherever the picker left the photo — not yet copied into app
  /// storage. That only happens on [ReceiptItemsCubit.submit], so
  /// backing out of this screen never leaves an orphaned file behind.
  final String sourcePath;

  final ReceiptItemsStatus status;
  final String? accountId;
  final List<Account> accounts;

  /// Expense categories, for the per-item category picker.
  final List<Category> categories;
  final String? errorMessage;

  bool get isSaving => status == ReceiptItemsStatus.saving;

  int get includedCount => items.where((i) => i.included).length;

  /// At least one item checked, and every checked item has a real
  /// positive amount — an unchecked item's amount is never validated,
  /// since it won't be saved.
  bool get canSave {
    final included = items.where((i) => i.included);
    return included.isNotEmpty && included.every((i) => i.hasValidAmount);
  }

  ReceiptItemsState copyWith({
    String? merchant,
    DateTime? transactedAt,
    List<ReceiptItemDraft>? items,
    ReceiptItemsStatus? status,
    String? accountId,
    List<Account>? accounts,
    List<Category>? categories,
    String? errorMessage,
  }) {
    return ReceiptItemsState(
      merchant: merchant ?? this.merchant,
      transactedAt: transactedAt ?? this.transactedAt,
      items: items ?? this.items,
      sourcePath: sourcePath,
      status: status ?? this.status,
      accountId: accountId ?? this.accountId,
      accounts: accounts ?? this.accounts,
      categories: categories ?? this.categories,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [
    merchant,
    transactedAt,
    items,
    sourcePath,
    status,
    accountId,
    accounts,
    categories,
    errorMessage,
  ];
}
