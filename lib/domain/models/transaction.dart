import 'package:equatable/equatable.dart';
import 'package:intellispendiq/domain/models/enums.dart';

/// A persisted transaction, as the rest of the app sees it.
///
/// Deliberately not the Drift row. The row stores what SQLite can hold —
/// ISO strings, status codes, a JSON blob — and every screen that touched
/// one used to re-decode those by hand. Here the decoding happens once,
/// at the repository boundary, so a cubit cannot forget to call
/// `toLocal()` or compare a status against the wrong string spelling.
class Transaction extends Equatable {
  const Transaction({
    required this.id,
    required this.accountId,
    required this.amountMinor,
    required this.currency,
    required this.direction,
    required this.transactedAt,
    required this.source,
    required this.status,
    required this.idempotencyKey,
    this.categoryId,
    this.merchant,
    this.description,
    this.confidence,
    this.rawCaptureId,
    this.duplicateOfId,
    this.paymentMethod,
    this.externalRef,
    this.metadata = const {},
    this.receiptPath,
    this.payeeId,
  });

  final String id;
  final String accountId;
  final String? categoryId;

  /// Absolute amount in minor units (ngwee). Always positive; [direction]
  /// carries the sign.
  final int amountMinor;
  final String currency;
  final TxDirection direction;
  final String? merchant;
  final String? description;

  /// Always UTC. Call `toLocal()` at the point of display.
  final DateTime transactedAt;
  final TxSource source;

  /// Extraction confidence, for voice entries only.
  final double? confidence;
  final TxStatus status;

  /// The raw capture this was parsed from, when it came from one.
  final String? rawCaptureId;
  final String idempotencyKey;

  /// The transaction this one is suspected of duplicating.
  final String? duplicateOfId;
  final String? paymentMethod;

  /// Provider TID / bank reference.
  final String? externalRef;

  /// Decoded from the stored JSON blob, so callers never parse it.
  final Map<String, Object?> metadata;

  /// Path to a receipt photo copied into app-local storage, if attached.
  final String? receiptPath;

  /// Structured payee, when one was picked rather than left as free
  /// text in [merchant]/[description].
  final String? payeeId;

  @override
  List<Object?> get props => [
    id,
    accountId,
    categoryId,
    amountMinor,
    currency,
    direction,
    merchant,
    description,
    transactedAt,
    source,
    confidence,
    status,
    rawCaptureId,
    idempotencyKey,
    duplicateOfId,
    paymentMethod,
    externalRef,
    metadata,
    receiptPath,
    payeeId,
  ];
}
