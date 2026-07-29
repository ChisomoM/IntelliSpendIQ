import 'package:equatable/equatable.dart';
import 'package:intellispendiq/domain/models/enums.dart';

/// A persisted capture, before or after parsing.
///
/// This is what survives even when parsing fails — see
/// `CaptureService`. The Review Inbox reads these directly, so the
/// original text and the failure reason both need to reach the UI
/// exactly as stored, which is the whole point of keeping this a
/// distinct type from `CaptureInput`.
class RawCapture extends Equatable {
  const RawCapture({
    required this.id,
    required this.channel,
    required this.body,
    required this.receivedAt,
    required this.parseStatus,
    required this.contentHash,
    this.sender,
    this.androidSmsId,
    this.packageName,
    this.parserKey,
    this.error,
    this.parsedTransactionId,
  });

  final String id;
  final CaptureChannel channel;

  /// SMS address or notification package.
  final String? sender;

  /// The captured text. Never dropped.
  final String body;

  /// Always UTC.
  final DateTime receivedAt;

  /// Native SMS `_id`, for backfill dedupe.
  final String? androidSmsId;
  final String? packageName;
  final ParseStatus parseStatus;
  final String? parserKey;

  /// Why parsing failed, or the reason a capture was ignored — shown
  /// verbatim in the Review Inbox.
  final String? error;
  final String? parsedTransactionId;
  final String contentHash;

  @override
  List<Object?> get props => [
    id,
    channel,
    sender,
    body,
    receivedAt,
    androidSmsId,
    packageName,
    parseStatus,
    parserKey,
    error,
    parsedTransactionId,
    contentHash,
  ];
}
