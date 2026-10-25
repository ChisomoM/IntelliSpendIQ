import 'package:equatable/equatable.dart';
import 'package:intellispendiq/domain/models/category.dart';
import 'package:intellispendiq/domain/models/shopping_trip.dart';

/// One top-level expense category's envelope for the trip's period and
/// what was already spent against it before the trip.
class CategoryEnvelope extends Equatable {
  const CategoryEnvelope({
    required this.categoryId,
    this.envelopeMinor,
    this.spentMinor = 0,
  });

  final String categoryId;

  /// Null when the category has no budget this period.
  final int? envelopeMinor;

  /// Confirmed spend so far, subcategories rolled up: the same figure
  /// the Budgets screen shows.
  final int spentMinor;

  @override
  List<Object?> get props => [categoryId, envelopeMinor, spentMinor];
}

enum TripSeverity { ok, near, over }

/// How the trip stands against one category's envelope.
class TripCategoryLine extends Equatable {
  const TripCategoryLine({
    required this.categoryId,
    required this.spentMinor,
    required this.cartMinor,
    required this.toBuyMinor,
    required this.onList,
    this.envelopeMinor,
  });

  /// Top-level category id, or null for items without a category.
  final String? categoryId;
  final int? envelopeMinor;
  final int spentMinor;

  /// In-cart total for this category.
  final int cartMinor;

  /// Planned lines not yet in the cart.
  final int toBuyMinor;

  /// Whether a planned or wishlist line put this category on the list.
  /// Only these feed the trip budget.
  final bool onList;

  bool get hasBudget => envelopeMinor != null;

  /// Envelope minus what was spent before the trip. Can be negative
  /// when the category was already over.
  int? get roomMinor => hasBudget ? envelopeMinor! - spentMinor : null;

  /// Room left after the cart.
  int? get leftMinor => hasBudget ? roomMinor! - cartMinor : null;

  /// Room left once everything still to buy is bought as planned.
  int? get freeMinor => hasBudget ? leftMinor! - toBuyMinor : null;

  bool get isOver => hasBudget && leftMinor! < 0;

  int get overByMinor => isOver ? -leftMinor! : 0;

  /// Fraction of the envelope used, spend before the trip included.
  double get usedRatio {
    if (!hasBudget || envelopeMinor! <= 0) return 0;
    return (spentMinor + cartMinor) / envelopeMinor!;
  }

  /// Nearing the limit: 80% or more used, with something in the cart
  /// for this category, so a category that was already high before the
  /// trip does not alert on its own.
  TripSeverity get severity {
    if (!hasBudget) return TripSeverity.ok;
    if (isOver) return TripSeverity.over;
    if (cartMinor > 0 && usedRatio >= ShoppingTripCalculator.nearRatio) {
      return TripSeverity.near;
    }
    return TripSeverity.ok;
  }

  @override
  List<Object?> get props => [
    categoryId,
    envelopeMinor,
    spentMinor,
    cartMinor,
    toBuyMinor,
    onList,
  ];
}

class TripSummary extends Equatable {
  const TripSummary({
    required this.lines,
    required this.cartTotalMinor,
    required this.impulseMinor,
    required this.toBuyMinor,
    required this.budgetMinor,
    required this.leftMinor,
    required this.overByMinor,
  });

  static const empty = TripSummary(
    lines: [],
    cartTotalMinor: 0,
    impulseMinor: 0,
    toBuyMinor: 0,
    budgetMinor: 0,
    leftMinor: 0,
    overByMinor: 0,
  );

  final List<TripCategoryLine> lines;

  /// Everything in the cart.
  final int cartTotalMinor;

  /// The part of the cart that was not on the list.
  final int impulseMinor;

  /// Planned lines not yet in the cart.
  final int toBuyMinor;

  /// Sum of the room in every budgeted category on the list.
  final int budgetMinor;

  /// Room left across the budgeted categories on the list. A category
  /// that is over never borrows from another: it counts as zero here
  /// and shows up in [overByMinor].
  final int leftMinor;

  /// Total overspend across every budgeted category, listed or not.
  final int overByMinor;

  bool get isOver => overByMinor > 0;

  /// Impulse share of the cart, 0 to 1.
  double get impulseShare =>
      cartTotalMinor == 0 ? 0 : impulseMinor / cartTotalMinor;

  List<TripCategoryLine> get overLines => lines.where((l) => l.isOver).toList();

  TripSeverity get severity {
    var worst = TripSeverity.ok;
    for (final line in lines) {
      if (line.severity.index > worst.index) worst = line.severity;
    }
    return worst;
  }

  TripCategoryLine? lineFor(String? categoryId) {
    for (final line in lines) {
      if (line.categoryId == categoryId) return line;
    }
    return null;
  }

  @override
  List<Object?> get props => [
    lines,
    cartTotalMinor,
    impulseMinor,
    toBuyMinor,
    budgetMinor,
    leftMinor,
    overByMinor,
  ];
}

enum AffordVerdict {
  /// Fits, and everything still to buy would too.
  yes,

  /// Fits now, but leaves too little for what is still on the list.
  tight,

  /// Puts the category over its envelope.
  no,

  /// The category has no budget, so there is nothing to check against.
  noBudget,
}

class AffordAnswer extends Equatable {
  const AffordAnswer({
    required this.verdict,
    required this.totalMinor,
    this.categoryId,
    this.leftAfterMinor,
    this.overByMinor = 0,
    this.shortForListMinor = 0,
  });

  final AffordVerdict verdict;
  final int totalMinor;
  final String? categoryId;

  /// Room left in the category after buying it. Null with no budget.
  final int? leftAfterMinor;
  final int overByMinor;

  /// For [AffordVerdict.tight]: how far the remaining planned items
  /// would then overshoot.
  final int shortForListMinor;

  @override
  List<Object?> get props => [
    verdict,
    totalMinor,
    categoryId,
    leftAfterMinor,
    overByMinor,
    shortForListMinor,
  ];
}

/// Pure trip arithmetic: no database, no clock, so the numbers a
/// shopper sees are the same ones the tests check.
abstract final class ShoppingTripCalculator {
  /// Share of an envelope at which the trip starts warning.
  static const nearRatio = 0.8;

  /// The top-level expense category [categoryId] counts against, or
  /// null for an item without one. A subcategory's spend counts toward
  /// its parent's envelope, so that is where its trip lines land too.
  static String? topLevelId(
    String? categoryId,
    Map<String, Category> categoriesById,
  ) {
    var current = categoryId == null ? null : categoriesById[categoryId];
    if (current == null) return categoryId;
    var guard = 0;
    while (current!.parentId != null && guard++ < 8) {
      final parent = categoriesById[current.parentId];
      if (parent == null) break;
      current = parent;
    }
    return current.id;
  }

  static TripSummary summarize({
    required List<ShoppingTripItem> items,
    required Map<String, CategoryEnvelope> envelopes,
    required Map<String, Category> categoriesById,
  }) {
    final keys = <String?>[];
    final cart = <String?, int>{};
    final toBuy = <String?, int>{};
    final onList = <String?>{};
    var cartTotal = 0;
    var impulse = 0;
    var toBuyTotal = 0;

    for (final item in items) {
      final key = topLevelId(item.categoryId, categoriesById);
      if (!keys.contains(key)) keys.add(key);
      if (item.isPlanned) onList.add(key);
      if (item.inCart) {
        cart[key] = (cart[key] ?? 0) + item.lineTotalMinor;
        cartTotal += item.lineTotalMinor;
        if (item.isImpulse) impulse += item.lineTotalMinor;
      } else if (item.isPlanned) {
        toBuy[key] = (toBuy[key] ?? 0) + item.lineTotalMinor;
        toBuyTotal += item.lineTotalMinor;
      }
    }

    final lines = <TripCategoryLine>[
      for (final key in keys)
        TripCategoryLine(
          categoryId: key,
          envelopeMinor: key == null ? null : envelopes[key]?.envelopeMinor,
          spentMinor: key == null ? 0 : (envelopes[key]?.spentMinor ?? 0),
          cartMinor: cart[key] ?? 0,
          toBuyMinor: toBuy[key] ?? 0,
          onList: onList.contains(key),
        ),
    ];

    var budget = 0;
    var left = 0;
    var overBy = 0;
    for (final line in lines) {
      if (!line.hasBudget) continue;
      overBy += line.overByMinor;
      if (!line.onList) continue;
      final room = line.roomMinor!;
      budget += room < 0 ? 0 : room;
      final lineLeft = line.leftMinor!;
      left += lineLeft < 0 ? 0 : lineLeft;
    }

    return TripSummary(
      lines: lines,
      cartTotalMinor: cartTotal,
      impulseMinor: impulse,
      toBuyMinor: toBuyTotal,
      budgetMinor: budget,
      leftMinor: left,
      overByMinor: overBy,
    );
  }

  /// "Can I afford this?": summarises the trip as if the item were
  /// already in the cart and reads the answer off its category.
  static AffordAnswer canAfford({
    required List<ShoppingTripItem> items,
    required Map<String, CategoryEnvelope> envelopes,
    required Map<String, Category> categoriesById,
    required int unitPriceMinor,
    int quantity = 1,
    String? categoryId,
  }) {
    final total = unitPriceMinor * quantity;
    final hypothetical = ShoppingTripItem(
      id: '_afford',
      tripId: '_afford',
      kind: ShoppingItemKind.impulse,
      name: '',
      categoryId: categoryId,
      unitPriceMinor: unitPriceMinor,
      quantity: quantity,
      inCart: true,
    );
    final summary = summarize(
      items: [...items, hypothetical],
      envelopes: envelopes,
      categoriesById: categoriesById,
    );
    final key = topLevelId(categoryId, categoriesById);
    final line = summary.lineFor(key)!;
    if (!line.hasBudget) {
      return AffordAnswer(
        verdict: AffordVerdict.noBudget,
        totalMinor: total,
        categoryId: key,
      );
    }
    if (line.isOver) {
      return AffordAnswer(
        verdict: AffordVerdict.no,
        totalMinor: total,
        categoryId: key,
        leftAfterMinor: line.leftMinor,
        overByMinor: line.overByMinor,
      );
    }
    final free = line.freeMinor!;
    return AffordAnswer(
      verdict: free < 0 ? AffordVerdict.tight : AffordVerdict.yes,
      totalMinor: total,
      categoryId: key,
      leftAfterMinor: line.leftMinor,
      shortForListMinor: free < 0 ? -free : 0,
    );
  }
}
