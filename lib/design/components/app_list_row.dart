import 'package:flutter/material.dart';
import 'package:intellispendiq/design/tokens/spacing.dart';
import 'package:intellispendiq/design/tokens/typography.dart';

/// The one row shape for lists across the app: leading avatar/icon,
/// title, optional subtitle, trailing content (usually a [MoneyText]
/// or a chevron). Always at least 48dp tall, per the guide's touch
/// target floor.
class AppListRow extends StatelessWidget {
  const AppListRow({
    required this.title,
    this.leading,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.onLongPress,
    super.key,
  });

  final Widget title;
  final Widget? leading;
  final Widget? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    final row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: Space.x6),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Space.gutter,
          vertical: Space.x1,
        ),
        child: Row(
          children: [
            if (leading != null) ...[leading!, const SizedBox(width: Space.x2)],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  DefaultTextStyle(
                    style: AppTypography.rowTitle(color: colors.onSurface),
                    overflow: TextOverflow.ellipsis,
                    child: title,
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    DefaultTextStyle(
                      style: AppTypography.metadata(
                        color: colors.onSurfaceVariant,
                      ),
                      overflow: TextOverflow.ellipsis,
                      child: subtitle!,
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: Space.x2),
              trailing!,
            ],
          ],
        ),
      ),
    );

    if (onTap == null && onLongPress == null) return row;
    return InkWell(onTap: onTap, onLongPress: onLongPress, child: row);
  }
}
