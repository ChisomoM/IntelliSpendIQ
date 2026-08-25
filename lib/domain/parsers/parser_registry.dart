import 'package:intellispendiq/core/ids.dart';
import 'package:intellispendiq/domain/models/capture_input.dart';
import 'package:intellispendiq/domain/models/parse_result.dart';
import 'package:intellispendiq/domain/parsers/airtel_money_parser.dart';
import 'package:intellispendiq/domain/parsers/mtn_momo_parser.dart';
import 'package:intellispendiq/domain/parsers/parser_provider.dart';
import 'package:intellispendiq/domain/parsers/stanchart_parser.dart';

/// Routes raw captures to the provider parser matching their sender.
class ParserRegistry {
  ParserRegistry({List<ParserProvider>? providers})
    : providers =
          providers ??
          [AirtelMoneyParser(), MtnMoMoParser(), StanChartParser()];

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
    final matches = _providersFor(sender);
    return matches.isEmpty ? null : matches.first;
  }

  bool isKnownSender(String? sender) => findBySender(sender) != null;

  /// Parses a capture with the provider matching its sender.
  ///
  /// When more than one provider claims the sender (Airtel Money and
  /// MTN MoMo both see `24783566639`), each is tried until one
  /// succeeds. Returns null when no provider claims the sender
  /// (capture should be stored as `ignored`, not `failed`).
  (ParserProvider, ParseResult)? parse(CaptureInput capture) {
    final matches = _providersFor(capture.sender);
    if (matches.isEmpty) return null;

    ParseFailure? firstFailure;
    ParserProvider? firstProvider;
    for (final provider in matches) {
      final result = provider.parse(capture);
      switch (result) {
        case ParseSuccess():
          return (provider, result);
        case ParseFailure():
          firstFailure ??= result;
          firstProvider ??= provider;
      }
    }
    return (firstProvider!, firstFailure!);
  }

  /// Custom mappings first, then every built-in provider that lists
  /// this sender — a shared numeric gateway can belong to more than
  /// one wallet.
  List<ParserProvider> _providersFor(String? sender) {
    if (sender == null) return const [];
    final normalized = Ids.normalizeSender(sender);
    final matches = <ParserProvider>[];
    final seen = <String>{};

    void consider(ParserProvider provider) {
      if (seen.add(provider.key)) matches.add(provider);
    }

    final customProviderKey = _customSenderProviderKeys[normalized];
    if (customProviderKey != null) {
      for (final provider in providers) {
        if (provider.key == customProviderKey) {
          consider(provider);
          break;
        }
      }
    }

    for (final provider in providers) {
      if (provider.senderIds.contains(normalized)) consider(provider);
    }
    return matches;
  }
}
