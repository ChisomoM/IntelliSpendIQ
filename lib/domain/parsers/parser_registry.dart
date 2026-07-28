import 'package:intellispendiq/core/ids.dart';
import 'package:intellispendiq/domain/models/capture_input.dart';
import 'package:intellispendiq/domain/models/parse_result.dart';
import 'package:intellispendiq/domain/parsers/airtel_money_parser.dart';
import 'package:intellispendiq/domain/parsers/parser_provider.dart';
import 'package:intellispendiq/domain/parsers/stanchart_parser.dart';

/// Routes raw captures to the provider parser matching their sender.
class ParserRegistry {
  ParserRegistry({List<ParserProvider>? providers})
    : providers = providers ?? [AirtelMoneyParser(), StanChartParser()];

  final List<ParserProvider> providers;

  /// All sender IDs the registry knows, normalized. Used to filter the
  /// inbox backfill to known senders only.
  Set<String> get knownSenderIds =>
      providers.expand((p) => p.senderIds).toSet();

  ParserProvider? findBySender(String? sender) {
    if (sender == null) return null;
    final normalized = Ids.normalizeSender(sender);
    for (final provider in providers) {
      if (provider.senderIds.contains(normalized)) return provider;
    }
    return null;
  }

  bool isKnownSender(String? sender) => findBySender(sender) != null;

  /// Parses a capture with the provider matching its sender.
  /// Returns null when no provider claims the sender (capture should be
  /// stored as `ignored`, not `failed`).
  (ParserProvider, ParseResult)? parse(CaptureInput capture) {
    final provider = findBySender(capture.sender);
    if (provider == null) return null;
    return (provider, provider.parse(capture));
  }
}
