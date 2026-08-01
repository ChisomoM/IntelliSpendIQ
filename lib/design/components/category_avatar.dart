import 'package:flutter/material.dart';
import 'package:intellispendiq/design/components/app_icon.dart';
import 'package:intellispendiq/design/tokens/category_palette.dart';
import 'package:intellispendiq/design/tokens/icons.dart';
import 'package:intellispendiq/design/tokens/radii.dart';

/// A category's glyph on its own tinted chip.
///
/// The colour is the category's, not the theme's. Every avatar in the
/// app used to be `colorScheme.secondary` at 12% — one flat violet, so
/// Food, Transport and Shopping rendered as identical swatches and a
/// list of them read as wallpaper. Hue now comes from
/// [CategoryPalette], keyed to the category so it never moves.
class CategoryAvatar extends StatelessWidget {
  const CategoryAvatar({
    required this.iconKey,
    this.categoryId,
    this.colorName,
    this.size = 40,
    super.key,
  });

  /// Icon key from `categories.icon`.
  final String? iconKey;

  /// Which category this is, so its hue stays put.
  final String? categoryId;

  /// `Category.color`, when the user has pinned one.
  final String? colorName;

  final double size;

  @override
  Widget build(BuildContext context) {
    final hue = CategoryPalette.forCategory(
      categoryId: categoryId,
      storedColor: colorName,
      brightness: Theme.of(context).brightness,
    );

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        // A very slight wash rather than a flat fill, so a column of
        // these catches light consistently instead of reading as a
        // strip of stickers.
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.alphaBlend(hue.ink.withValues(alpha: 0.06), hue.tint),
            hue.tint,
          ],
        ),
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      alignment: Alignment.center,
      child: AppIcon(
        CategoryIcons.byKey(iconKey),
        size: size * 0.5,
        color: hue.ink,
      ),
    );
  }
}
