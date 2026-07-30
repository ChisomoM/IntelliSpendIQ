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

  /// User-added sender IDs (normalized) mapped to an existing
  /// provider's key, layered on top of each provider's built-in
  /// [ParserProvider.senderIds] — for a bank or wallet whose alerts
  /// arrive from a shortcode the built-in list doesn't recognize.
  final Map<String, String> _customSenderProviderKeys = {};

  /// Replaces the whole custom-sender map, e.g. loading it from
  /// storage at startup.
  void setCustomSenders(Map<String, String> senderIdToProviderKey) {
    _customSenderProviderKeys
      ..clear()
      ..addEntries(
        senderIdToProviderKey.entries.map(
          (entry) => MapEntry(Ids.normalizeSender(entry.key), entry.value),
        ),
      );
  }

  void addCustomSender(String providerKey, String senderId) {
    _customSenderProviderKeys[Ids.normalizeSender(senderId)] = providerKey;
  }

  void removeCustomSender(String senderId) {
    _customSenderProviderKeys.remove(Ids.normalizeSender(senderId));
  }

  /// All sender IDs the registry knows, normalized. Used to filter the
  /// inbox backfill to known senders only.
  Set<String> get knownSenderIds => {
    ...providers.expand((p) => p.senderIds),
    ..._customSenderProviderKeys.keys,
  };

  ParserProvider? findBySender(String? sender) {
    if (sender == null) return null;
    final normalized = Ids.normalizeSender(sender);

    final customProviderKey = _customSenderProviderKeys[normalized];
    if (customProviderKey != null) {
      for (final provider in providers) {
        if (provider.key == customProviderKey) return provider;
      }
    }

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
