import 'package:flutter/material.dart';

/// One category hue, in the three roles a category colour actually
/// plays: a fill behind its glyph, an ink for the glyph itself, and a
/// solid series colour for a chart mark.
class CategoryHue {
  const CategoryHue({
    required this.name,
    required this.tint,
    required this.ink,
    required this.series,
  });

  final String name;

  /// Background of the avatar chip.
  final Color tint;

  /// The glyph on [tint]. Every pair here clears 4.5:1.
  final Color ink;

  /// A solid mark in a chart, measured against the chart surface
  /// rather than against [tint].
  final Color series;
}

/// The app's categorical palette.
///
/// Every value below was produced by the data-viz validator against
/// this app's own surfaces (white in light mode, `night800` cards in
/// dark), not chosen by eye. What that buys:
///
/// - **Five hues, not eight.** Green and red are deliberately absent:
///   this app already spends those two on money direction, and a green
///   *category* sitting beside a green *inflow* argues with the ledger.
/// - **No violet.** The brand reserves violet for actions and active
///   state. A violet category swatch would read as a button.
/// - **The order is the safety mechanism, not decoration.** Of the 5040
///   orderings of seven candidate hues, four cleared every colour-vision
///   gate in both modes; dropping green and red left this one. Reordering
///   these slots silently breaks the guarantee — re-run the validator if
///   you ever do.
/// - Every tint/ink pair clears 4.5:1, so the glyph is legible on its
///   own chip in both themes.
///
/// Colour is never the only channel: a category always ships its own
/// glyph and its name beside it.
abstract final class CategoryPalette {
  static const _light = <CategoryHue>[
    CategoryHue(
      name: 'blue',
      tint: Color(0xFFE5EFFA),
      ink: Color(0xFF266CC1),
      series: Color(0xFF2A78D6),
    ),
    CategoryHue(
      name: 'orange',
      tint: Color(0xFFFDEDE7),
      ink: Color(0xFFB04E27),
      series: Color(0xFFEB6834),
    ),
    CategoryHue(
      name: 'aqua',
      tint: Color(0xFFE4F5EF),
      ink: Color(0xFF137A55),
      series: Color(0xFF1BAF7A),
    ),
    CategoryHue(
      name: 'yellow',
      tint: Color(0xFFFDF4E0),
      ink: Color(0xFF8E6100),
      series: Color(0xFFEDA100),
    ),
    CategoryHue(
      name: 'magenta',
      tint: Color(0xFFFCEFF4),
      ink: Color(0xFFA25673),
      series: Color(0xFFE87BA4),
    ),
  ];

  /// Not a brightness flip of [_light] — each hue is re-stepped for the
  /// dark surface and validated as its own set.
  static const _dark = <CategoryHue>[
    CategoryHue(
      name: 'blue',
      tint: Color(0xFF1F325D),
      ink: Color(0xFF5AA0EE),
      series: Color(0xFF3987E5),
    ),
    CategoryHue(
      name: 'orange',
      tint: Color(0xFF362B42),
      ink: Color(0xFFF0743F),
      series: Color(0xFFD95926),
    ),
    CategoryHue(
      name: 'aqua',
      tint: Color(0xFF1B354D),
      ink: Color(0xFF25C88D),
      series: Color(0xFF199E70),
    ),
    CategoryHue(
      name: 'yellow',
      tint: Color(0xFF33323D),
      ink: Color(0xFFE8AB1F),
      series: Color(0xFFC98500),
    ),
    CategoryHue(
      name: 'magenta',
      tint: Color(0xFF352A4F),
      ink: Color(0xFFE87FA6),
      series: Color(0xFFD55181),
    ),
  ];

  static List<CategoryHue> of(Brightness brightness) =>
      brightness == Brightness.dark ? _dark : _light;

  /// One hue, light to dark, for magnitude — the spend heatmap.
  ///
  /// Sequential encoding is a single hue ramped by lightness, never a
  /// spread of hues: the calendar used to `Color.lerp` between
  /// `primaryContainer` and `primary`, which walked through violet mush
  /// and gave no readable sense of "how much".
  static const _sequentialLight = <Color>[
    Color(0xFFCDE2FB),
    Color(0xFF9EC5F4),
    Color(0xFF6DA7EC),
    Color(0xFF3987E5),
    Color(0xFF256ABF),
    Color(0xFF184F95),
  ];

  /// Dark mode ramps the other way — away from the surface, not toward
  /// black, or the busiest days would vanish into the background.
  static const _sequentialDark = <Color>[
    Color(0xFF184F95),
    Color(0xFF256ABF),
    Color(0xFF2A78D6),
    Color(0xFF3987E5),
    Color(0xFF6DA7EC),
    Color(0xFF9EC5F4),
  ];

  /// Picks a sequential step for [t] in 0..1.
  static Color sequential(double t, Brightness brightness) {
    final ramp = brightness == Brightness.dark
        ? _sequentialDark
        : _sequentialLight;
    final index = (t.clamp(0.0, 1.0) * (ramp.length - 1)).round();
    return ramp[index];
  }

  static int get slotCount => _light.length;

  /// The hue for [slot], wrapping if asked for more than there are.
  static CategoryHue bySlot(int slot, Brightness brightness) {
    final hues = of(brightness);
    return hues[slot.abs() % hues.length];
  }

  /// A stable slot for [categoryId].
  ///
  /// Keyed to the entity, never to its position in a list — a category
  /// must not change colour because something above it was renamed,
  /// deleted, or outspent it this month. Two categories can land on the
  /// same hue; their glyph and name still tell them apart, and that is
  /// a better trade than a colour that moves.
  static int slotFor(String categoryId) {
    // FNV-1a: stable across runs and platforms, unlike String.hashCode.
    var hash = 0x811c9dc5;
    for (final unit in categoryId.codeUnits) {
      hash = (hash ^ unit) * 0x01000193;
      hash &= 0xFFFFFFFF;
    }
    return hash % slotCount;
  }

  /// Resolves a category's hue: an explicit stored colour wins, and
  /// otherwise the hue is derived from the id.
  ///
  /// [storedColor] is `Category.color` — a field carried by the
  /// repository, both cubits and the backup format, which until now
  /// nothing ever rendered.
  static CategoryHue forCategory({
    required String? categoryId,
    String? storedColor,
    required Brightness brightness,
  }) {
    final named = _byName(storedColor, brightness);
    if (named != null) return named;
    if (categoryId == null) return of(brightness).first;
    return bySlot(slotFor(categoryId), brightness);
  }

  static CategoryHue? _byName(String? name, Brightness brightness) {
    if (name == null) return null;
    for (final hue in of(brightness)) {
      if (hue.name == name) return hue;
    }
    return null;
  }
}
