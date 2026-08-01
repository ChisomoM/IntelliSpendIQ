import 'package:flutter/material.dart';
import 'package:intellispendiq/design/tokens/colors.dart';

/// Gradients, kept to a short list so they read as a system rather than
/// decoration sprinkled per screen.
///
/// Every stop below was contrast-checked against the ink it carries:
/// `nightText` clears 13:1 on the lightest hero stop and `nightText2`
/// clears 6.7:1, so a gradient never quietly costs legibility at one
/// end of its run.
abstract final class AppGradients {
  /// The headline surface — Home's hero and the budget hero. Runs from
  /// a violet-tinged dark into the ink, so the card has depth without
  /// becoming a second brand colour.
  static const heroLight = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF2A1A5E), AppColors.ink900],
  );

  /// Dark mode keeps the same move but inside the night ramp — a
  /// lighter surface reading as raised, which is how elevation is
  /// expressed in dark mode here.
  static const heroDark = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.night700, AppColors.night900],
  );

  static LinearGradient hero(Brightness brightness) =>
      brightness == Brightness.dark ? heroDark : heroLight;

  /// The primary action. Light mode runs violet600 → violet500 so the
  /// FAB has a lit edge; dark mode runs the cyan the scheme uses there.
  static const actionLight = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.violet500, AppColors.violet700],
  );

  static const actionDark = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.cyan300, AppColors.cyan500],
  );

  static LinearGradient action(Brightness brightness) =>
      brightness == Brightness.dark ? actionDark : actionLight;

  /// A very quiet wash for a chip or avatar in [color]'s hue — top-left
  /// slightly stronger, so a grid of them catches light consistently
  /// rather than looking like flat stickers.
  static LinearGradient tint(Color color) => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [color, Color.alphaBlend(color.withValues(alpha: 0.55), color)],
  );

  /// Softens the leading edge of a coloured bar so a meter reads as a
  /// filled volume rather than a flat block.
  static LinearGradient meter(Color color) => LinearGradient(
    colors: [color.withValues(alpha: 0.75), color],
  );
}

/// Shadows. Light mode only — dark-mode elevation is surface lightness,
/// never a shadow, so [card] and [raised] return empty there.
abstract final class AppShadows {
  static List<BoxShadow> card(Brightness brightness) {
    if (brightness == Brightness.dark) return const [];
    return const [
      BoxShadow(
        color: Color(0x0F0D173B),
        blurRadius: 16,
        offset: Offset(0, 4),
      ),
      BoxShadow(
        color: Color(0x080D173B),
        blurRadius: 2,
        offset: Offset(0, 1),
      ),
    ];
  }

  /// For the hero and the docked FAB, which sit above the card plane.
  static List<BoxShadow> raised(Brightness brightness) {
    if (brightness == Brightness.dark) return const [];
    return const [
      BoxShadow(
        color: Color(0x1F0D173B),
        blurRadius: 28,
        offset: Offset(0, 10),
      ),
    ];
  }
}
