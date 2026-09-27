import 'package:equatable/equatable.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:intellispendiq/core/money.dart';

/// Fields lifted from a receipt photo by on-device OCR — no external AI
/// call, matching the rest of the capture pipeline (README: "SMS parsing
/// is deterministic"). Any field the scan couldn't find is left null so
/// the caller never overwrites something the user already typed.
class ReceiptScanResult extends Equatable {
  const ReceiptScanResult({
    this.merchant,
    this.amountMinor,
    this.transactedAt,
    required this.rawText,
  });

  final String? merchant;
  final int? amountMinor;
  final DateTime? transactedAt;

  /// Full OCR text, kept for debugging a bad scan.
  final String rawText;

  @override
  List<Object?> get props => [merchant, amountMinor, transactedAt, rawText];
}

/// Scans a receipt photo with on-device text recognition (Google ML Kit,
/// runs locally — nothing leaves the phone) and pulls out a best-guess
/// merchant, total and date with plain regex/heuristics. Deliberately not
/// LLM-backed: receipts are noisy OCR text, and a wrong silent guess here
/// is worse than a blank field the user fills in by hand.
class ReceiptScanner {
  ReceiptScanner({TextRecognizer? recognizer})
    : _recognizer = recognizer ?? TextRecognizer();

  final TextRecognizer _recognizer;

  Future<ReceiptScanResult> scanImage(String imagePath) async {
    final recognized = await _recognizer.processImage(
      InputImage.fromFilePath(imagePath),
    );
    return parseText(recognized.text);
  }

  Future<void> dispose() => _recognizer.close();

  /// Matches a "total" line: `TOTAL`, `Grand Total`, `Amount Due`,
  /// `Balance Due`, but not `Subtotal` (fixed-length negative lookbehind
  /// on "sub"), followed within a short gap by a decimal amount.
  static final RegExp _totalLine = RegExp(
    r'(?<!sub)(?:total|amount\s*due|balance\s*due)\b[^0-9]{0,20}'
    r'([0-9][0-9,]*\.[0-9]{2})',
    caseSensitive: false,
  );

  static final RegExp _isoDate = RegExp(
    r'\b(20[0-9]{2})[/-]([0-1]?[0-9])[/-]([0-3]?[0-9])\b',
  );

  static final RegExp _slashDate = RegExp(
    r'\b([0-3]?[0-9])[/-]([0-1]?[0-9])[/-]((?:20)?[0-9]{2})\b',
  );

  /// Lines that are clearly not a merchant name — a date, an amount-only
  /// line, or too short/symbol-heavy to be one.
  static final RegExp _looksLikeDataLine = RegExp(
    r'^[0-9\s./:,-]*$|total|receipt|invoice|thank you|tel:|vat|tax',
    caseSensitive: false,
  );

  /// Pure parsing over already-recognized text, split out from
  /// [scanImage] so it can be unit tested without a real image or
  /// ML Kit's platform channel.
  static ReceiptScanResult parseText(String rawText) {
    return ReceiptScanResult(
      merchant: _extractMerchant(rawText),
      amountMinor: _extractTotalMinor(rawText),
      transactedAt: _extractDate(rawText),
      rawText: rawText,
    );
  }

  static String? _extractMerchant(String text) {
    for (final line in text.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.length < 3 || trimmed.length > 40) continue;
      if (!RegExp('[A-Za-z]{3,}').hasMatch(trimmed)) continue;
      if (_looksLikeDataLine.hasMatch(trimmed)) continue;
      return trimmed;
    }
    return null;
  }

  static int? _extractTotalMinor(String text) {
    int? best;
    for (final match in _totalLine.allMatches(text)) {
      final minor = Money.tryParseToMinor(match.group(1)!);
      if (minor == null) continue;
      // A receipt's grand total is its largest labeled total line —
      // subtotals and per-item "total" labels are smaller.
      if (best == null || minor > best) best = minor;
    }
    return best;
  }

  static DateTime? _extractDate(String text) {
    final iso = _isoDate.firstMatch(text);
    if (iso != null) {
      final date = _tryDate(
        year: int.parse(iso.group(1)!),
        month: int.parse(iso.group(2)!),
        day: int.parse(iso.group(3)!),
      );
      if (date != null) return date;
    }
    final slash = _slashDate.firstMatch(text);
    if (slash != null) {
      final yearRaw = slash.group(3)!;
      final year = yearRaw.length == 2
          ? 2000 + int.parse(yearRaw)
          : int.parse(yearRaw);
      final date = _tryDate(
        year: year,
        month: int.parse(slash.group(2)!),
        day: int.parse(slash.group(1)!),
      );
      if (date != null) return date;
    }
    return null;
  }

  static DateTime? _tryDate({
    required int year,
    required int month,
    required int day,
  }) {
    if (month < 1 || month > 12 || day < 1 || day > 31) return null;
    final date = DateTime(year, month, day);
    // DateTime normalizes an out-of-range day (e.g. Feb 30) by rolling
    // into the next month instead of throwing — reject that silently.
    if (date.month != month || date.day != day) return null;
    return date;
  }
}
