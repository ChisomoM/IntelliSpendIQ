import 'package:flutter/material.dart';

abstract final class Radii {
  static const double card = 12;
  static const double input = 12;
  static const double chip = 999;
  static const double fab = 18;

  /// Top-only radius for bottom sheets.
  static const double sheet = 20;

  static const cardRadius = BorderRadius.all(Radius.circular(card));
  static const inputRadius = BorderRadius.all(Radius.circular(input));
  static const chipRadius = BorderRadius.all(Radius.circular(chip));

  /// Not a circle, per the brand guide — the FAB is a rounded square.
  static const fabShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(fab)),
  );

  static const sheetRadius = BorderRadius.only(
    topLeft: Radius.circular(sheet),
    topRight: Radius.circular(sheet),
  );
}
