import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Type scale from the brand guide (§3), set in Plus Jakarta Sans.
///
/// The guide names IBM Plex. Plex Mono's typewriter shapes read as
/// "terminal" rather than "money" beside the rest of the interface, and
/// running Plex Sans against it gave the app two voices that never
/// quite agreed. Plus Jakarta Sans replaces both: one geometric family
/// with real tabular figures, so amounts still align on the decimal
/// without a second typeface doing it.
///
/// Sizes, line heights, tracking and the 13px floor are unchanged — the
/// only substitution is the family. Reverting is a one-line change in
/// [_font].
///
/// The 11px chip/overline style is the single exception to the floor,
/// and it is always uppercase and tracked, never a sentence.
abstract final class AppTypography {
  /// The one family. Swap this to change the whole app's voice.
  static TextStyle _font({
    required double size,
    required double height,
    required FontWeight weight,
    double letterSpacing = 0,
    Color? color,
    List<FontFeature>? features,
  }) {
    return GoogleFonts.plusJakartaSans(
      fontSize: size,
      height: height / size,
      fontWeight: weight,
      letterSpacing: letterSpacing,
      color: color,
      fontFeatures: features,
    );
  }

  static TextStyle _sans({
    required double size,
    required double height,
    required FontWeight weight,
    double letterSpacing = 0,
    Color? color,
  }) => _font(
    size: size,
    height: height,
    weight: weight,
    letterSpacing: letterSpacing,
    color: color,
  );

  /// Numeric styles. Tabular figures are what keep a column of amounts
  /// aligned on the decimal — that was mono's real job, not its look.
  static TextStyle _mono({
    required double size,
    required double height,
    required FontWeight weight,
    double letterSpacing = 0,
    Color? color,
  }) => _font(
    size: size,
    height: height,
    weight: weight,
    letterSpacing: letterSpacing,
    color: color,
    features: const [FontFeature.tabularFigures()],
  );

  /// Reserved for onboarding and long-form insight copy.
  static TextStyle serif({
    double size = 17,
    double height = 26,
    FontWeight weight = FontWeight.w400,
    FontStyle style = FontStyle.normal,
    Color? color,
  }) {
    return GoogleFonts.fraunces(
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
