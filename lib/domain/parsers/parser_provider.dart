import 'package:intellispendiq/core/ids.dart';
import 'package:intellispendiq/domain/models/capture_input.dart';
import 'package:intellispendiq/domain/models/parse_result.dart';

/// One provider (bank / mobile money operator) worth of SMS parsing
/// rules. Adding a new provider means adding a new implementation and
/// registering it — no engine rewrite.
abstract class ParserProvider {
  /// Stable key stored on accounts and raw captures,
  /// e.g. `airtel_money`, `stan_chart`.
  String get key;

  /// Human-readable provider name, e.g. "Airtel Money".
  String get displayName;

  /// Sender IDs (already normalized via [Ids.normalizeSender]) this
  /// provider's messages arrive from.
  Set<String> get senderIds;

  /// Whether [capture]'s sender matches this provider.
  bool canParse(CaptureInput capture) {
    final sender = capture.sender;
    if (sender == null) return false;
    return senderIds.contains(Ids.normalizeSender(sender));
  }

  /// Runs deterministic rules over the body. Never throws: unparseable
  /// bodies return [ParseResult.failure].
  ParseResult parse(CaptureInput capture);
}
