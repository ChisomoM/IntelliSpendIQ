import 'package:intl/intl.dart';

/// Money helpers. All amounts are stored as integer minor units
/// (ngwee — 1 ZMW = 100 ngwee) to avoid float rounding bugs (D60).
///
/// Formatting follows the brand guide, which is stricter than it looks:
///
/// | Rule | Correct | Wrong |
/// |---|---|---|
/// | Symbol | `K1,250.00` | `ZMW 1250`, `K 1250/=` |
/// | Thousands | `K12,480.00` | `K12480.00` |
/// | Outflow | `−K89.00` | `(K89.00)`, `K-89` |
/// | Inflow | `+K3,000.00` | `K3,000.00` |
/// | Charts, headlines | `K12.5k` | `K12,480` on an axis |
/// | ISO code `ZMW` | statements & export | never in the ledger |
abstract final class Money {
  /// Used for statements and export only — never on a transaction row.
  static const String isoCode = 'ZMW';

  /// The display symbol. No space before the digits.
  static const String symbol = 'K';

  /// True minus, U+2212 — not a hyphen. It aligns with the digit stroke,
  /// which is the whole reason a column of amounts lines up.
  static const String minus = '−';

  static const String plus = '+';

  static final NumberFormat _majorFormat = NumberFormat('#,##0.00', 'en');
  static final NumberFormat _compactFormat = NumberFormat('#,##0.#', 'en');

  /// Matches an amount token like `10`, `10.5`, `1,350.00`.
  static final RegExp _amountToken = RegExp(
    r'^([0-9][0-9,]*)(?:\.([0-9]{1,2}))?$',
  );

  /// Parses an amount string (as it appears in SMS bodies or user input)
  /// into integer minor units without going through doubles.
  ///
  /// Accepts `1350`, `1,350.00`, `10.5`, `0.75`, and tolerates a leading
  /// `K` or `ZMW`. Returns null when the string is not a plain positive
  /// amount.
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

  /// The ledger form: `K1,350.00`. Ngwee are always shown here.
  ///
  /// A negative [amountMinor] takes a true minus. This is the plain
  /// magnitude renderer — for a signed inflow/outflow pair use [signed],
  /// which is explicit about direction rather than inferring it.
  static String format(int amountMinor, {String? currency}) {
    final sign = amountMinor < 0 ? minus : '';
    return '$sign${_unsigned(amountMinor.abs(), currency)}';
  }

  /// The directional form: `+K3,000.00` for money in, `−K89.00` for
  /// money out.
  ///
  /// Direction is passed in rather than read off the sign of
  /// [amountMinor], because the ledger stores every amount as a positive
  /// magnitude with a separate direction column.
  static String signed(
    int amountMinor, {
    required bool isInflow,
    String? currency,
  }) {
    final sign = isInflow ? plus : minus;
    return '$sign${_unsigned(amountMinor.abs(), currency)}';
  }

  /// The rounded form for chart axes and headline figures: `K12.5k`.
  /// Ngwee are always dropped here — a full amount on an axis is noise.
  static String compact(int amountMinor, {String? currency}) {
    final sign = amountMinor < 0 ? minus : '';
    final prefix = currency == null ? symbol : '$currency ';
    final major = amountMinor.abs() / 100;

    final (value, suffix) = switch (major) {
      >= 1000000 => (major / 1000000, 'm'),
      >= 1000 => (major / 1000, 'k'),
      _ => (major, ''),
    };

    return '$sign$prefix${_compactFormat.format(value)}$suffix';
  }

  /// The statement and export form: `ZMW 1,350.00`. This is the only
  /// place the ISO code is allowed to appear.
  static String withIsoCode(int amountMinor, {String currency = isoCode}) {
    final sign = amountMinor < 0 ? '-' : '';
    return '$sign$currency ${_majorFormat.format(_major(amountMinor.abs()))}';
  }

  /// `K1,350.00` for the default currency, `USD 1,350.00` for anything
  /// else — the bare `K` symbol only means kwacha, so a foreign-currency
  /// amount has to say which currency it is.
  static String _unsigned(int amountMinor, String? currency) {
    final formatted = _majorFormat.format(_major(amountMinor));
    if (currency == null || currency == isoCode) return '$symbol$formatted';
    return '$currency $formatted';
  }

  /// Minor units to major, without going through a lossy division.
  static double _major(int amountMinor) =>
      amountMinor ~/ 100 + (amountMinor % 100) / 100;
}
