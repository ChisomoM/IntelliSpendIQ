import 'package:equatable/equatable.dart';
import 'package:intellispendiq/core/money.dart';

/// Structured result of the voice → transaction LLM extraction
/// (plan §12 JSON contract). Amounts cross the boundary as doubles from
/// the model and are immediately converted to integer minor units —
/// never trust the float past this point.
class TransactionExtraction extends Equatable {
  const TransactionExtraction({
    required this.amountMinor,
    required this.confidence,
    this.currency = 'ZMW',
    this.categoryGuess,
    this.merchantGuess,
    this.paymentMethod,
    this.date,
    this.direction = 'debit',
  });

  factory TransactionExtraction.fromJson(Map<String, dynamic> json) {
    final amount = json['amount'];
    return TransactionExtraction(
      amountMinor: amount is num
          ? Money.minorFromDouble(amount.toDouble())
          : null,
      currency: (json['currency'] as String?) ?? 'ZMW',
      categoryGuess: json['category_guess'] as String?,
      merchantGuess: json['merchant_guess'] as String?,
      paymentMethod: (json['payment_method'] as String?) ?? 'cash',
      date: json['date'] as String?,
      direction: (json['direction'] as String?) ?? 'debit',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0,
    );
  }

  /// Amount in ngwee; null when the model could not find an amount.
  final int? amountMinor;
  final String currency;
  final String? categoryGuess;
  final String? merchantGuess;
  final String? paymentMethod;

  /// ISO date (YYYY-MM-DD) or null → today.
  final String? date;

  /// `debit` | `credit`.
  final String direction;
  final double confidence;

  @override
  List<Object?> get props => [
    amountMinor,
    currency,
    categoryGuess,
    merchantGuess,
    paymentMethod,
    date,
    direction,
    confidence,
  ];
}

/// Thrown when extraction fails (network, refusal, malformed response).
/// Callers leave the item in the Review Inbox — never dropped.
class AiExtractionException implements Exception {
  AiExtractionException(this.message);

  final String message;

  @override
  String toString() => 'AiExtractionException: $message';
}
