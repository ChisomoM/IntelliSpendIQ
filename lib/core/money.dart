import 'package:intl/intl.dart';

/// Money helpers. All amounts are stored as integer minor units
/// (ngwee — 1 ZMW = 100 ngwee) to avoid float rounding bugs (D60).
abstract final class Money {
  static const String defaultCurrency = 'ZMW';

  static final NumberFormat _majorFormat = NumberFormat('#,##0.00', 'en');

  /// Matches an amount token like `10`, `10.5`, `1,350.00`.
  static final RegExp _amountToken = RegExp(
    r'^([0-9][0-9,]*)(?:\.([0-9]{1,2}))?$',
  );

  /// Parses an amount string (as it appears in SMS bodies or user input)
  /// into integer minor units without going through doubles.
  ///
  /// Accepts `1350`, `1,350.00`, `10.5`, `0.75`. Returns null when the
  /// string is not a plain positive amount.
  static int? tryParseToMinor(String raw) {
    final cleaned = raw
        .trim()
        .replaceFirst(RegExp('^(ZMW|K)', caseSensitive: false), '')
        .trim();
    final match = _amountToken.firstMatch(cleaned.replaceAll(' ', ''));
    if (match == null) return null;
    final wholePart = match.group(1)!.replaceAll(',', '');
    final whole = int.tryParse(wholePart);
    if (whole == null) return null;
    final centsRaw = match.group(2);
    final cents = centsRaw == null
        ? 0
        : int.parse(centsRaw.length == 1 ? '${centsRaw}0' : centsRaw);
    return whole * 100 + cents;
  }

  /// Converts a double amount (e.g. from LLM extraction JSON) to minor
  /// units, rounding to the nearest ngwee. Never trust the float past
  /// this boundary.
  static int minorFromDouble(double amount) => (amount * 100).round();

  /// Formats minor units for display, e.g. `ZMW 1,350.00`.
  static String format(int amountMinor, {String currency = defaultCurrency}) {
    final sign = amountMinor < 0 ? '-' : '';
    final abs = amountMinor.abs();
    return '$sign$currency ${_majorFormat.format(abs ~/ 100 + (abs % 100) / 100)}';
  }
}
