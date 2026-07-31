import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Type scale from the brand guide (§3).
///
/// Three families, each with one job: Sans is the interface, Mono is
/// every number, Serif is reserved for onboarding/insights/wrap-style
/// copy and never appears in app chrome.
///
/// Every Mono style carries tabular figures so amounts align on the
/// decimal in a column. 13px is the floor for on-screen text; the 11px
/// chip/overline style is the one sanctioned exception, and it is
/// always uppercase and tracked, never a sentence.
abstract final class AppTypography {
  static TextStyle _sans({
    required double size,
    required double height,
    required FontWeight weight,
    double letterSpacing = 0,
    Color? color,
  }) {
    return GoogleFonts.ibmPlexSans(
      fontSize: size,
      height: height / size,
      fontWeight: weight,
      letterSpacing: letterSpacing,
      color: color,
    );
  }

  static TextStyle _mono({
    required double size,
    required double height,
    required FontWeight weight,
    double letterSpacing = 0,
    Color? color,
  }) {
    return GoogleFonts.ibmPlexMono(
      fontSize: size,
      height: height / size,
      fontWeight: weight,
      letterSpacing: letterSpacing,
      color: color,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
  }

  /// Onboarding / insights / monthly-wrap copy only — never app chrome.
  static TextStyle serif({
    double size = 17,
    double height = 26,
    FontWeight weight = FontWeight.w400,
    FontStyle style = FontStyle.normal,
    Color? color,
  }) {
    return GoogleFonts.ibmPlexSerif(
      fontSize: size,
      height: height / size,
      fontWeight: weight,
      fontStyle: style,
      color: color,
    );
  }

  /// 34/38, mono 600, −0.02em. The large amount on a summary card.
  static TextStyle balanceDisplay({Color? color}) => _mono(
    size: 34,
    height: 38,
    weight: FontWeight.w600,
    letterSpacing: -0.02 * 34,
    color: color,
  );

  /// 24/30, sans 600, −0.01em. A screen's own title.
  static TextStyle screenTitle({Color? color}) => _sans(
    size: 24,
    height: 30,
    weight: FontWeight.w600,
    letterSpacing: -0.01 * 24,
    color: color,
  );

  /// 17/24, sans 600. A section label within a screen.
  static TextStyle sectionHeader({Color? color}) =>
      _sans(size: 17, height: 24, weight: FontWeight.w600, color: color);

  /// 16/22, sans 500. A row's primary label — merchant, category name.
  static TextStyle rowTitle({Color? color}) =>
      _sans(size: 16, height: 22, weight: FontWeight.w500, color: color);

  /// 16/22, mono 600, tabular. A row's trailing amount.
  static TextStyle rowAmount({Color? color}) =>
      _mono(size: 16, height: 22, weight: FontWeight.w600, color: color);

  /// 15/23, sans 400. Ordinary body copy.
  static TextStyle body({Color? color}) =>
      _sans(size: 15, height: 23, weight: FontWeight.w400, color: color);

  /// 13/18, sans 400. The metadata floor — timestamps, legal text.
  /// Never go smaller than this outside [chipOverline].
  static TextStyle metadata({Color? color}) =>
      _sans(size: 13, height: 18, weight: FontWeight.w400, color: color);

  /// 11/14, mono 500, 0.08em, uppercase. Chips and overlines only —
  /// the single exception to the 13px floor. Callers must uppercase
  /// the string themselves; this style does not transform it.
  static TextStyle chipOverline({Color? color}) => _mono(
    size: 11,
    height: 14,
    weight: FontWeight.w500,
    letterSpacing: 0.08 * 11,
    color: color,
  );

  /// 13/18, mono 500, tabular — [metadata]'s size in the mono family,
  /// for a small amount inside a caption or a chip. Kept as its own
  /// method rather than `metadata().copyWith(fontFamily: ...)`, which
  /// would leave Sans's font-fallback chain attached to a Mono family
  /// name.
  static TextStyle metaAmount({Color? color}) =>
      _mono(size: 13, height: 18, weight: FontWeight.w500, color: color);
}
