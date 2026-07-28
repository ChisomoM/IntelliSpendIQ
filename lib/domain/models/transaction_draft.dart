import 'package:equatable/equatable.dart';
import 'package:intellispendiq/domain/models/enums.dart';

/// A parsed-but-not-yet-persisted transaction produced by SMS parsers,
/// voice extraction, or manual entry. Repositories turn drafts into rows;
/// parsers never touch the database or UI state.
class TransactionDraft extends Equatable {
  const TransactionDraft({
    required this.amountMinor,
    required this.direction,
    required this.source,
    required this.transactedAt,
    this.currency = 'ZMW',
    this.merchant,
    this.description,
    this.categoryId,
    this.paymentMethod,
    this.externalRef,
    this.confidence,
    this.balanceMinor,
    this.typeHint,
    this.feeMinor,
    this.metadata = const {},
  });

  /// Absolute amount in minor units (ngwee). Always positive.
  final int amountMinor;
  final TxDirection direction;
  final TxSource source;
  final DateTime transactedAt;
  final String currency;
  final String? merchant;
  final String? description;
  final String? categoryId;
  final String? paymentMethod;

  /// Provider transaction reference (TID / bank ref) when present.
  final String? externalRef;
  final double? confidence;

  /// Account balance reported by the provider message, informational only.
  final int? balanceMinor;

  /// Parser rule family that produced this draft, e.g. `payment_till`.
  final String? typeHint;

  /// Non-zero provider charge to be recorded as a separate fee line.
  final int? feeMinor;
  final Map<String, Object?> metadata;

  TransactionDraft copyWith({
    int? amountMinor,
    TxDirection? direction,
    String? merchant,
    String? description,
    String? categoryId,
    String? paymentMethod,
    DateTime? transactedAt,
    double? confidence,
  }) {
    return TransactionDraft(
      amountMinor: amountMinor ?? this.amountMinor,
      direction: direction ?? this.direction,
      source: source,
      transactedAt: transactedAt ?? this.transactedAt,
      currency: currency,
      merchant: merchant ?? this.merchant,
      description: description ?? this.description,
      categoryId: categoryId ?? this.categoryId,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      externalRef: externalRef,
      confidence: confidence ?? this.confidence,
      balanceMinor: balanceMinor,
      typeHint: typeHint,
      feeMinor: feeMinor,
      metadata: metadata,
    );
  }

  @override
  List<Object?> get props => [
    amountMinor,
    direction,
    source,
    transactedAt,
    currency,
    merchant,
    description,
    categoryId,
    paymentMethod,
    externalRef,
    confidence,
    balanceMinor,
    typeHint,
    feeMinor,
    metadata,
  ];
}
