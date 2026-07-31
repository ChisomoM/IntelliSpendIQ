import 'package:flutter/material.dart';
import 'package:intellispendiq/app/theme/tokens.dart';
import 'package:intellispendiq/app/theme/typography.dart';

/// The standard container. Hairline plus a very soft shadow in light
/// mode; in dark mode the shadow is dropped entirely and the card is
/// separated by being lighter than the page behind it.
class AppCard extends StatelessWidget {
  const AppCard({
    required this.child,
    this.padding = const EdgeInsets.all(Space.lg),
    this.onTap,
    this.color,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final radius = BorderRadius.circular(Radii.card);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: color ?? theme.cardTheme.color,
        borderRadius: radius,
        border: Border.all(color: theme.colorScheme.outlineVariant),
        boxShadow: isDark
            ? null
            : const [
                BoxShadow(
                  color: Color(0x0A16161A),
                  blurRadius: 2,
                  offset: Offset(0, 1),
                ),
              ],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// A titled break in a page, with an optional one-line explanation and
/// an optional trailing action.
class SectionHeading extends StatelessWidget {
  const SectionHeading(
    this.title, {
    this.subtitle,
    this.action,
    this.padding = const EdgeInsets.fromLTRB(Space.lg, Space.xxl, Space.lg, 0),
    super.key,
  });

  final String title;
  final String? subtitle;
  final Widget? action;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: AppText.sectionHeader.copyWith(
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
              ?action,
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: Space.xs),
            Text(
              subtitle!,
              style: AppText.metadata.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A row in a list. Enforces the 48dp touch floor rather than relying on
/// whatever the content happens to measure.
class AppListRow extends StatelessWidget {
  const AppListRow({
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.padding = const EdgeInsets.symmetric(
      horizontal: Space.lg,
      vertical: Space.md,
    ),
    super.key,
  });

  /// Free-form so a caller can mark one field as uncertain without this
  /// widget knowing anything about confidence.
  final Widget title;
  final Widget? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: padding,
            child: Row(
              children: [
                if (leading != null) ...[
                  leading!,
                  const SizedBox(width: Space.md),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      title,
                      if (subtitle != null) ...[
                        const SizedBox(height: Space.xxs),
                        subtitle!,
                      ],
                    ],
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: Space.md),
                  trailing!,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A circular icon holder for the leading slot of a row.
class RowIcon extends StatelessWidget {
  const RowIcon(this.icon, {this.background, this.foreground, super.key});

  final IconData icon;
  final Color? background;
  final Color? foreground;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: background ?? scheme.surfaceContainerHigh,
        shape: BoxShape.circle,
      ),
      child: Icon(
        icon,
        size: 20,
        color: foreground ?? scheme.onSurfaceVariant,
      ),
    );
  }
}
