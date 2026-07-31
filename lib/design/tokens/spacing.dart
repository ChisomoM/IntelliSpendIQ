/// 8dp grid. Every spacing value in the app is one of these — no
/// widget reaches for a bare `SizedBox(height: 12)` or a hand-picked
/// `EdgeInsets` any more.
abstract final class Space {
  static const double x1 = 8;
  static const double x2 = 16;
  static const double x3 = 24;
  static const double x4 = 32;
  static const double x5 = 40;
  static const double x6 = 48;

  /// Left/right screen margin.
  static const double gutter = x2;

  /// Padding inside a card or sheet.
  static const double cardPadding = x2;

  /// Gap between two stacked cards.
  static const double cardGap = x1;

  /// Gap between distinct sections on a screen.
  static const double sectionGap = x3;
}
