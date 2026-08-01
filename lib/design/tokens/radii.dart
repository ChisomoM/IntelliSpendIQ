import 'package:flutter/material.dart';

abstract final class Radii {
  /// Softer than the 12 the brand guide names. With the card border
  /// gone, 12 read as a slightly-rounded rectangle; 16 reads as a
  /// surface. Chips, the FAB and sheets keep their specified radii.
  static const double card = 16;
  static const double input = 14;
  static const double chip = 999;
  static const double fab = 18;

  /// The headline card, rounder still so it reads as the one object on
  /// the screen that is not a list item.
  static const double hero = 24;

  /// Top-only radius for bottom sheets.
  static const double sheet = 24;

  static const cardRadius = BorderRadius.all(Radius.circular(card));
  static const inputRadius = BorderRadius.all(Radius.circular(input));
  static const chipRadius = BorderRadius.all(Radius.circular(chip));
  static const heroRadius = BorderRadius.all(Radius.circular(hero));

  /// Not a circle, per the brand guide — the FAB is a rounded square.
  static const fabShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(fab)),
  );

  static const sheetRadius = BorderRadius.only(
    topLeft: Radius.circular(sheet),
    topRight: Radius.circular(sheet),
  );
}
