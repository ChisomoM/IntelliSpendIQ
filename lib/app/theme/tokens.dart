import 'package:flutter/material.dart';

/// Raw design tokens. Nothing in the app reads a hex value directly —
/// widgets go through [ColorScheme] or the `MoneyColors` extension, so
/// this file is the only place a colour is written down.
///
/// Contrast ratios in the comments are measured against the surface the
/// token is actually used on, and are the reason each value was picked.
abstract final class AppColors {
  // ---------------------------------------------------------------
  // Ink — the light-mode neutral ramp.
  // ---------------------------------------------------------------

  /// Card fill in light mode.
  static const paper = Color(0xFFFFFFFF);

  /// App background in light mode. Cards are [paper] sitting on this.
  static const ink050 = Color(0xFFF4F4F3);

  /// Chip fill, high container.
  static const ink100 = Color(0xFFE8E8E6);

  /// Card hairline.
  static const ink200 = Color(0xFFDCDCD9);

  /// Borders and icons *only* — never text. 3.03:1 on [paper], which is
  /// the floor for non-text contrast (WCAG 1.4.11).
  static const ink300 = Color(0xFF94948D);

  /// The text floor in light mode: metadata, timestamps, placeholders.
  /// 5.06:1 on [paper].
  static const ink400 = Color(0xFF6E6E68);

  /// The dot on an SMS source chip.
  static const ink500 = Color(0xFF565650);

  /// Source-chip label.
  static const ink700 = Color(0xFF33332F);

  /// Primary text in light mode, and the label on a cyan fill in dark.
  /// 18.3:1 on [paper].
  static const ink900 = Color(0xFF16161A);

  // ---------------------------------------------------------------
  // Night — the dark-mode ramp. Depth is lightness, never shadow.
  // ---------------------------------------------------------------

  /// App background in dark mode.
  static const night900 = Color(0xFF0F0F12);

  /// Cards, sitting on [night900].
  static const night800 = Color(0xFF17171B);

  /// Sheets, menus and chips — the top surface level.
  static const night700 = Color(0xFF1F1F25);

  /// Decorative card hairline. Deliberately low contrast: in dark mode
  /// the card is separated by its own lightness, so the line is trim
  /// rather than the thing doing the work.
  static const nightLine = Color(0xFF35353E);

  /// Borders that are load-bearing — input outlines, dividers that
  /// carry meaning. 3.4:1 on [night900], so it clears non-text contrast
  /// where [nightLine] would not.
  static const nightLineStrong = Color(0xFF6A6A75);

  /// Primary text in dark mode.
  static const nightText = Color(0xFFEDEDF0);

  /// Secondary text in dark mode. 7.4:1 on [night900].
  static const nightText2 = Color(0xFFA0A0A8);

  // ---------------------------------------------------------------
  // Brand.
  // ---------------------------------------------------------------

  /// Voice source-chip fill in light mode.
  static const violet100 = Color(0xFFEDE9FE);

  /// Dark-mode accent and links on dark. **Never** text or fill on a
  /// light surface — it lands around 1.7:1 there, with no size or
  /// weight exception.
  static const violet300 = Color(0xFFB69CFF);

  /// Primary fill in light mode. 6.07:1 with white on top.
  static const violet600 = Color(0xFF6C3CE9);

  /// Links and the focus ring in light mode. 7.6:1 on [paper].
  static const violet700 = Color(0xFF5A2FD0);

  /// Dark-mode primary. Dark surfaces only, at most once per screen.
  /// 10.7:1 carrying an [ink900] label.
  static const cyan300 = Color(0xFF4FD8E8);

  // ---------------------------------------------------------------
  // Money. Direction, not alarm — see [MoneyColors].
  // ---------------------------------------------------------------

  /// 5.3:1 on [paper].
  static const inflowLight = Color(0xFF0E7A5F);

  /// 6.6:1 on [paper].
  static const outflowLight = Color(0xFFB3261E);

  /// The "we guessed this" colour. 5.2:1 on [paper].
  static const reviewLight = Color(0xFFA15C00);

  static const inflowDark = Color(0xFF4ADE9E);

  /// 8.3:1 on [night900].
  static const outflowDark = Color(0xFFFF8A80);

  static const reviewDark = Color(0xFFF0B429);
}

/// Four-point spacing scale. Every gap in the app is one of these.
abstract final class Space {
  static const xxs = 2.0;
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const xxl = 24.0;
  static const xxxl = 32.0;
  static const huge = 40.0;
  static const giant = 48.0;
  static const massive = 64.0;
}

abstract final class Radii {
  static const card = 12.0;
  static const button = 12.0;
  static const input = 10.0;

  /// The FAB is a rounded rectangle, not a circle.
  static const fab = 18.0;

  /// Bottom sheets round their top corners only.
  static const sheet = 20.0;

  /// Chips are fully rounded; large enough to always win the clamp.
  static const chip = 999.0;
}

/// Motion tokens. Callers must still gate on
/// `MediaQuery.disableAnimationsOf(context)` — see [Motion.duration].
abstract final class Motion {
  /// A captured row arriving in the ledger: fade plus an 8dp rise.
  static const rowArrival = Duration(milliseconds: 180);

  /// How long an undo snackbar holds before it starts to fade.
  static const undoHold = Duration(milliseconds: 2000);
  static const undoFade = Duration(milliseconds: 150);

  static const sheetOpen = Duration(milliseconds: 240);

  static const rowRise = 8.0;

  static const Curve arrivalCurve = Curves.easeOut;
  static const Curve sheetCurve = Curves.decelerate;

  /// Collapses [d] to zero when the platform has animations turned off,
  /// so every animated widget in the app honours the system scale by
  /// asking for its duration through here.
  ///
  /// An amount is never animated at all, with or without this.
  static Duration duration(BuildContext context, Duration d) =>
      MediaQuery.disableAnimationsOf(context) ? Duration.zero : d;
}
