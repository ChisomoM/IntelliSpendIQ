import 'package:flutter/material.dart';
import 'package:intellispendiq/design/components/app_icon.dart';
import 'package:intellispendiq/design/tokens/icons.dart';
import 'package:intellispendiq/design/tokens/radii.dart';

/// A category's icon in a tinted rounded square — what every category
/// glyph in the app renders through, replacing the emoji that used to
/// sit directly in a `Text` widget.
///
/// Takes the stable icon key from `categories.icon` (see
/// [CategoryIcons]), not a raw `HugeIcons` constant, so a screen never
/// has to know the resolution rule itself.
class CategoryAvatar extends StatelessWidget {
  const CategoryAvatar({required this.iconKey, this.size = 40, super.key});

  final String? iconKey;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final icon = CategoryIcons.byKey(iconKey);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: colors.secondary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(Radii.card),
      ),
      alignment: Alignment.center,
      child: AppIcon(icon, size: size * 0.5, color: colors.secondary),
    );
  }
}
