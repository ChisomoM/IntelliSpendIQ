import 'package:flutter/material.dart';
import 'package:intellispendiq/design/tokens/gradients.dart';
import 'package:intellispendiq/design/tokens/radii.dart';
import 'package:intellispendiq/design/tokens/spacing.dart';

/// The one card shape in the app.
///
/// Light mode is a white surface lifted off the page plane by a soft
/// shadow — no outline. The 1px grey border this replaced drew a hard
/// rectangle around every group on the screen, so a scroll read as a
/// stack of boxes instead of content sitting on a plane.
///
/// Dark mode keeps the border and drops the shadow, because the brand
/// guide expresses dark elevation as surface lightness and a shadow on
/// near-black is invisible anyway — there, a hairline is the only thing
/// that separates a card from the page.
class AppCard extends StatelessWidget {
  const AppCard({
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(Space.cardPadding),
    super.key,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final content = Padding(padding: padding, child: child);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: isDark
            ? theme.colorScheme.surfaceContainerLow
            : theme.colorScheme.surface,
        borderRadius: Radii.cardRadius,
        border: isDark
            ? Border.all(color: theme.colorScheme.outlineVariant)
            : null,
        boxShadow: AppShadows.card(theme.brightness),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: Radii.cardRadius,
        clipBehavior: Clip.antiAlias,
        child: onTap == null
            ? content
            : InkWell(
                onTap: onTap,
                borderRadius: Radii.cardRadius,
                child: content,
              ),
      ),
    );
  }
}

/// The headline surface: a gradient card carrying the screen's one big
/// number. Dark in both themes, so its own ink is fixed rather than
/// taken from the scheme.
class HeroCard extends StatelessWidget {
  const HeroCard({
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(Space.x3),
    super.key,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final content = Padding(padding: padding, child: child);

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: AppGradients.hero(brightness),
        borderRadius: Radii.heroRadius,
        boxShadow: AppShadows.raised(brightness),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: Radii.heroRadius,
        clipBehavior: Clip.antiAlias,
        child: onTap == null
            ? content
            : InkWell(
                onTap: onTap,
                borderRadius: Radii.heroRadius,
                child: content,
              ),
      ),
    );
  }
}
