import 'package:flutter/material.dart';

/// Raw colour ramp from the brand guide. The only file in the app
/// allowed to contain a colour literal — everything else reads a
/// [ColorScheme] role or a [MoneyColors] / [CaptureColors] extension.
///
/// Role restrictions the guide places on these (enforce at call sites,
/// not here — this file only holds values):
/// - `cyan300` and `violet300` are never text or fill on a light surface.
/// - `cyan` appears at most once per screen, only on a dark surface.
/// - `violet` appears at most twice per screen: primary action + active
///   state marker.
/// - Text is never lighter than `ink400` in light mode, `nightText2` in
///   dark mode. `ink300` is borders and icons only.
abstract final class AppColors {
  // Neutrals — light mode.
  static const ink900 = Color(0xFF0D173B);
  static const ink700 = Color(0xFF1F2A4D);
  static const ink500 = Color(0xFF3A4565);
  static const ink400 = Color(0xFF5B6485);
  static const ink300 = Color(0xFF767E9A);
  static const ink200 = Color(0xFFC7CBDA);
  static const ink100 = Color(0xFFEEEEF7);
  static const ink050 = Color(0xFFF7F8FB);
  static const paper = Color(0xFFFFFFFF);

  // Neutrals — dark mode.
  static const night900 = Color(0xFF080D1F);
  static const night800 = Color(0xFF101733);
  static const night700 = Color(0xFF1B2447);
  static const nightLine = Color(0xFF2B3560);
  static const nightText = Color(0xFFEEF0F7);
  static const nightText2 = Color(0xFFA6AECB);

  // Action — violet.
  static const violet700 = Color(0xFF5B21B6);
  static const violet600 = Color(0xFF6D28D9);
  static const violet500 = Color(0xFF7C3AED);
  static const violet300 = Color(0xFF9D5BFF);
  static const violet100 = Color(0xFFF3EAFE);

  // Graphics only, dark surfaces — cyan.
  static const cyan700 = Color(0xFF055A6B);
  static const cyan500 = Color(0xFF0E9BB5);
  static const cyan300 = Color(0xFF03D8FD);
  static const cyan100 = Color(0xFFDDF7FE);

  // Money & state — light.
  static const inflow = Color(0xFF047857);
  static const outflow = Color(0xFFB91C1C);
  static const review = Color(0xFFB45309);

  // Money & state — dark.
  static const inflowD = Color(0xFF34D399);
  static const outflowD = Color(0xFFFF9B8F);
  static const reviewD = Color(0xFFF0B429);
}
