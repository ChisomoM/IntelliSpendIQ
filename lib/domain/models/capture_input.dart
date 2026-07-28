import 'package:equatable/equatable.dart';
import 'package:intellispendiq/domain/models/enums.dart';

/// A captured event (SMS, notification, or voice transcript) before it
/// has been persisted or parsed. Native code only forwards these —
/// all parsing stays in Dart.
class CaptureInput extends Equatable {
  const CaptureInput({
    required this.channel,
    required this.body,
    required this.receivedAt,
    this.sender,
    this.androidSmsId,
    this.packageName,
  });

  final CaptureChannel channel;

  /// SMS address or notification title context. Null for voice.
  final String? sender;
  final String body;
  final DateTime receivedAt;

  /// Native SMS `_id`, used for backfill dedupe.
  final String? androidSmsId;

  /// Source app package for notification captures.
  final String? packageName;

  @override
  List<Object?> get props => [
    channel,
    sender,
    body,
    receivedAt,
    androidSmsId,
    packageName,
  ];
}
