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

  /// Formats minor units with the ISO currency code, e.g.
  /// `ZMW 1,350.00`. Reserved for statements and CSV/JSON export — the
  /// brand guide keeps `ZMW` out of every other on-screen surface. Use
  /// [display] for the ledger, cards, and anywhere else in the UI.
  static String format(int amountMinor, {String currency = defaultCurrency}) {
    final sign = amountMinor < 0 ? '-' : '';
    final abs = amountMinor.abs();
    return '$sign$currency ${_majorFormat.format(abs ~/ 100 + (abs % 100) / 100)}';
  }

  /// True minus (U+2212), not a hyphen — it aligns with a digit's
  /// stroke width in tabular figures.
  static const _minus = '−';

  /// Formats minor units the way the ledger shows them: `K1,250.00`,
  /// no space after the symbol, no ISO code. Unsigned — pass a
  /// negative [amountMinor] only when the value is genuinely negative
  /// (e.g. "over by"), not to encode direction; use [displaySigned]
  /// for a ledger row where direction should render as `+`/`−`.
  static String display(int amountMinor) {
    final sign = amountMinor < 0 ? _minus : '';
    final abs = amountMinor.abs();
    return '$sign${_symbolPrefix(abs)}';
  }

  /// Formats a ledger row: `+K3,000.00` for money in, `−K89.00` for
  /// money out. [amountMinor] is always the absolute amount here —
  /// [isInflow] carries the direction, matching how the domain model
  /// stores transactions (amount is always positive; direction is a
  /// separate field).
  static String displaySigned(int amountMinor, {required bool isInflow}) {
    final sign = isInflow ? '+' : _minus;
    return '$sign${_symbolPrefix(amountMinor.abs())}';
  }

  /// [display], but for an amount that may not be in kwacha.
  ///
  /// Accounts carry their own currency, so a balance held in something
  /// else must not be printed with a `K` in front of it. Anything other
  /// than the home currency falls back to the ISO code.
  static String displayIn(int amountMinor, String currency) {
    if (currency == defaultCurrency) return display(amountMinor);
    return format(amountMinor, currency: currency);
  }

  /// Compact form for chart axes and headlines: `K12.5k` rather than
  /// `K12,480.00`. Ngwee are always dropped here, even when non-zero.
  static String displayCompact(int amountMinor) {
    final sign = amountMinor < 0 ? _minus : '';
    final majorUnits = amountMinor.abs() / 100;
    if (majorUnits < 1000) {
      return '$sign${defaultSymbol}${majorUnits.round()}';
    }
    final thousands = majorUnits / 1000;
    final rounded = (thousands * 10).round() / 10;
    final label = rounded == rounded.roundToDouble()
        ? rounded.toStringAsFixed(0)
        : rounded.toStringAsFixed(1);
    return '$sign$defaultSymbol${label}k';
  }

  static const defaultSymbol = 'K';

  static String _symbolPrefix(int absAmountMinor) {
    return '$defaultSymbol${_majorFormat.format(absAmountMinor ~/ 100 + (absAmountMinor % 100) / 100)}';
  }
}
