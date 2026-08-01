import 'package:intellispendiq/data/repositories/category_repository.dart';
import 'package:intellispendiq/data/repositories/merchant_category_rule_repository.dart';
import 'package:intellispendiq/domain/services/dedupe_service.dart';

/// Guesses a category for a captured SMS transaction, and learns from
/// the user's own corrections so the guess gets better over time.
///
/// Deterministic and LLM-free, matching the rest of the SMS pipeline
/// (README: "SMS parsing is deterministic"). Two layers, tried in order:
///
/// 1. A learned merchant → category rule, keyed by the same normalized
///    merchant `DedupeService` uses for fuzzy dedupe. Written the first
///    time a user recategorizes a transaction from that merchant, and
///    consulted before anything else on every later capture.
/// 2. A static keyword table matched against the merchant and message
///    text, for a sensible first guess before any correction exists.
///
/// A miss at both layers leaves the transaction uncategorized, same as
/// today — this never guesses wrong silently, it just sometimes doesn't
/// guess.
class MerchantCategorizer {
  MerchantCategorizer({
    required MerchantCategoryRuleRepository rules,
    required CategoryRepository categories,
  }) : _rules = rules,
       _categories = categories;

  final MerchantCategoryRuleRepository _rules;
  final CategoryRepository _categories;

  /// Keyword → seeded category name. Checked in order; the first match
  /// wins. Names match `CategoryRepository.seedNames` exactly so a
  /// fresh install always resolves them.
  static const List<(List<String>, String)> _keywordRules = [
    (
      [
        'airtime',
        'data bundle',
        ' data ',
        'bundle',
        'minutes',
        'top up',
        'topup',
        'recharge',
      ],
      'Airtime/Data',
    ),
    (
      [
        'shoprite',
        'game stores',
        'game store',
        'pick n pay',
        'choppies',
        'melissa',
        'mr price',
        'spar',
        'foodworld',
      ],
      'Shopping',
    ),
    (
      [
        'restaurant',
        'takeaway',
        'take away',
        'kfc',
        'hungry lion',
        'debonairs',
        'pizza',
        'cafe',
        'steers',
        'nandos',
        "nando's",
      ],
      'Food',
    ),
    (
      [
        'fuel',
        'puma energy',
        'total energies',
        'engen',
        'filling station',
        'service station',
        'petrol',
      ],
      'Transport',
    ),
  ];

  /// Best-guess category id for a capture, or null if neither the
  /// learned rules nor the keyword table matched.
  Future<String?> categorize({String? merchant, String? messageBody}) async {
    final normalized = DedupeService.normalizeMerchant(merchant);
    if (normalized.isNotEmpty) {
      final learned = await _rules.categoryIdFor(normalized);
      if (learned != null) return learned;
    }

    final haystack = ' ${merchant ?? ''} ${messageBody ?? ''} '.toLowerCase();
    for (final (keywords, categoryName) in _keywordRules) {
      if (keywords.any(haystack.contains)) {
        final category = await _categories.byName(categoryName);
        if (category != null) return category.id;
      }
    }
    return null;
  }

  /// Records that transactions from [merchant] should map to
  /// [categoryId] from now on — called whenever the user assigns or
  /// changes a transaction's category by hand.
  Future<void> learnFrom({
    required String? merchant,
    required String categoryId,
  }) async {
    final normalized = DedupeService.normalizeMerchant(merchant);
    if (normalized.isEmpty) return;
    await _rules.upsert(normalizedMerchant: normalized, categoryId: categoryId);
  }
}
