import 'package:flutter/material.dart';

/// IBM Plex, bundled in `assets/fonts/` rather than fetched, so the
/// offline-first promise holds literally — the app never needs a network
/// to render correctly.
abstract final class AppFonts {
  /// Interface, body, merchant names. Weights 400 / 500 / 600.
  static const sans = 'IBMPlexSans';

  /// **Every number, every amount.** Weights 500 / 600. Being monospaced
  /// is what makes a column of amounts align on the decimal, so the rule
  /// is structural rather than a font-feature flag.
  static const mono = 'IBMPlexMono';

  /// Onboarding, insights, the monthly wrap. Never in app chrome.
  static const serif = 'IBMPlexSerif';
}

/// The type scale. Sizes are logical px; `height` encodes the guide's
/// `size / line` pairs, and letter spacing converts the guide's `em`
/// values at each size.
///
/// **13px is the floor**, including timestamps and legal text. The 11px
/// [overline] is the single exception and is always uppercase and
/// tracked — never a sentence.
abstract final class AppText {
  static const _tabular = <FontFeature>[FontFeature.tabularFigures()];

  /// Mono 600, 34/38, −0.02em. The one big number on a screen.
  static const balance = TextStyle(
    fontFamily: AppFonts.mono,
    fontWeight: FontWeight.w600,
    fontSize: 34,
    height: 38 / 34,
    letterSpacing: -0.68,
    fontFeatures: _tabular,
  );

  /// Mono 600, 22/26. A secondary hero figure — a stat tile, a total.
  static const amountLarge = TextStyle(
    fontFamily: AppFonts.mono,
    fontWeight: FontWeight.w600,
    fontSize: 22,
    height: 26 / 22,
    letterSpacing: -0.22,
    fontFeatures: _tabular,
  );

  /// Mono 600, 16/22. The amount on a ledger row.
  static const amount = TextStyle(
    fontFamily: AppFonts.mono,
    fontWeight: FontWeight.w600,
    fontSize: 16,
    height: 22 / 16,
    fontFeatures: _tabular,
  );

  /// Mono 500, 13/18. An amount in a dense secondary position.
  static const amountSmall = TextStyle(
    fontFamily: AppFonts.mono,
    fontWeight: FontWeight.w500,
    fontSize: 13,
    height: 18 / 13,
    fontFeatures: _tabular,
  );

  /// Sans 600, 24/30, −0.01em.
  static const screenTitle = TextStyle(
    fontFamily: AppFonts.sans,
    fontWeight: FontWeight.w600,
    fontSize: 24,
    height: 30 / 24,
    letterSpacing: -0.24,
  );

  /// Sans 600, 17/24.
  static const sectionHeader = TextStyle(
    fontFamily: AppFonts.sans,
    fontWeight: FontWeight.w600,
    fontSize: 17,
    height: 24 / 17,
  );

  /// Sans 500, 16/22. A merchant name.
  static const rowTitle = TextStyle(
    fontFamily: AppFonts.sans,
    fontWeight: FontWeight.w500,
    fontSize: 16,
    height: 22 / 16,
  );

  /// Sans 400, 16/24. Form field contents.
  static const field = TextStyle(
    fontFamily: AppFonts.sans,
    fontSize: 16,
    height: 24 / 16,
  );

  /// Sans 400, 15/23.
  static const body = TextStyle(
    fontFamily: AppFonts.sans,
    fontSize: 15,
    height: 23 / 15,
  );

  /// Sans 400, 13/18. Timestamps, helper text — the smallest sentence
  /// the app is allowed to set.
  static const metadata = TextStyle(
    fontFamily: AppFonts.sans,
    fontSize: 13,
    height: 18 / 13,
  );

  /// Sans 600, 15/20. Button labels.
  static const button = TextStyle(
    fontFamily: AppFonts.sans,
    fontWeight: FontWeight.w600,
    fontSize: 15,
    height: 20 / 15,
  );

  /// Sans 500, 13/18.
  static const label = TextStyle(
    fontFamily: AppFonts.sans,
    fontWeight: FontWeight.w500,
    fontSize: 13,
    height: 18 / 13,
  );

  /// Mono 500, 11/14, 0.08em, uppercase. Chips and overlines only.
  static const overline = TextStyle(
    fontFamily: AppFonts.mono,
    fontWeight: FontWeight.w500,
    fontSize: 11,
    height: 14 / 11,
    letterSpacing: 0.88,
  );

  /// Serif 400, 17/27. Onboarding, insights, the monthly wrap.
  static const editorial = TextStyle(
    fontFamily: AppFonts.serif,
    fontSize: 17,
    height: 27 / 17,
  );

  /// Serif 500 italic, 19/29. A pulled-out editorial line.
  static const editorialQuote = TextStyle(
    fontFamily: AppFonts.serif,
    fontWeight: FontWeight.w500,
    fontStyle: FontStyle.italic,
    fontSize: 19,
    height: 29 / 19,
  );

  /// Maps the scale onto Material's slots so that stock widgets — and
  /// every screen not yet migrated to the named styles — inherit the
  /// right face without knowing about it.
  static TextTheme themeFor(Color onSurface, Color onSurfaceVariant) {
    return TextTheme(
      displayLarge: balance.copyWith(color: onSurface),
      displayMedium: balance.copyWith(color: onSurface),
      displaySmall: amountLarge.copyWith(color: onSurface),
      headlineLarge: screenTitle.copyWith(color: onSurface),
      headlineMedium: screenTitle.copyWith(color: onSurface),
      headlineSmall: screenTitle.copyWith(color: onSurface),
      titleLarge: screenTitle.copyWith(color: onSurface),
      titleMedium: sectionHeader.copyWith(color: onSurface),
      titleSmall: rowTitle.copyWith(color: onSurface),
      bodyLarge: field.copyWith(color: onSurface),
      bodyMedium: body.copyWith(color: onSurface),
      bodySmall: metadata.copyWith(color: onSurfaceVariant),
      labelLarge: button.copyWith(color: onSurface),
      labelMedium: label.copyWith(color: onSurfaceVariant),
      labelSmall: overline.copyWith(color: onSurfaceVariant),
    );
  }
}
