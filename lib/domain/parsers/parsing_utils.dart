import 'package:intellispendiq/core/money.dart';

/// Shared deterministic tokens used by provider parsers.
abstract final class ParsingUtils {
  /// Amount preceded by a currency marker: `K1,350.00`, `K300`, `K 300.00`.
  static const String currencyAmount =
      r'(?:ZMW|K)\s*([0-9][0-9,]*(?:\.[0-9]{1,2})?)';

  /// Airtel transaction reference: `MP260728.0729.D08222` after a
  /// `TID`/`Txn. ID` label, with or without a colon.
  static final RegExp airtelTid = RegExp(
    r'(?:TID|Txn\.?\s*ID)\s*:?\s*([A-Z]{2}[0-9]{6}\.[0-9]{4}\.[A-Z][0-9]+)',
  );

  /// Reported balance: `bal is K45.23`, `Bal K601.35`,
  /// `Your bal is K260.23`.
  static final RegExp balance = RegExp(
    r'[Bb]al(?:ance)?\s+(?:is\s+)?' + currencyAmount,
  );

  /// `Date: 26-July-2026 15:24` as embedded in some Airtel messages.
  static final RegExp embeddedDate = RegExp(
    r'Date:\s*([0-9]{1,2})-([A-Za-z]+)-([0-9]{4})\s+([0-9]{1,2}):([0-9]{2})',
  );

  static const Map<String, int> _months = {
    'january': 1,
    'february': 2,
    'march': 3,
    'april': 4,
    'may': 5,
    'june': 6,
    'july': 7,
    'august': 8,
    'september': 9,
    'october': 10,
    'november': 11,
    'december': 12,
  };

  static int? amountMinorFrom(RegExpMatch match, int group) {
    final raw = match.group(group);
    if (raw == null) return null;
    return Money.tryParseToMinor(raw);
  }

  static int? balanceMinor(String body) {
    final match = balance.firstMatch(body);
    if (match == null) return null;
    return amountMinorFrom(match, 1);
  }

  static String? tid(String body) => airtelTid.firstMatch(body)?.group(1);

  /// Parses an embedded `Date: dd-MonthName-yyyy HH:mm` as device-local
  /// time. Returns null when absent or malformed.
  static DateTime? embeddedDateTime(String body) {
    final match = embeddedDate.firstMatch(body);
    if (match == null) return null;
    final month = _months[match.group(2)!.toLowerCase()];
    if (month == null) return null;
    return DateTime(
      int.parse(match.group(3)!),
      month,
      int.parse(match.group(1)!),
      int.parse(match.group(4)!),
      int.parse(match.group(5)!),
    );
  }

  /// Splits a counterparty like `20068466 FELIX MONDE` or
  /// `0245970 NFS SETTLEMENT ACCOUNT` into (number, name). Returns the
  /// original string as name when there is no leading numeric token.
  static (String?, String) splitLeadingNumber(String counterparty) {
    final match = RegExp(
      r'^([0-9]{4,})\s+(.+)$',
    ).firstMatch(counterparty.trim());
    if (match == null) return (null, counterparty.trim());
    return (match.group(1), match.group(2)!.trim());
  }

  /// Strips trailing marketing URLs from a body before matching.
  static String stripTrailingLinks(String body) =>
      body.replaceAll(RegExp(r'https?://\S+\s*$'), '').trimRight();
}
