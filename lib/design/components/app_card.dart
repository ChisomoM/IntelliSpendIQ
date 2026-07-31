import 'package:flutter/material.dart';
import 'package:intellispendiq/design/tokens/radii.dart';
import 'package:intellispendiq/design/tokens/spacing.dart';

/// The one card shape in the app: `AppTheme.cardTheme` already sets
/// colour, border and radius, so this widget only standardises padding
/// and the optional tap ripple. No `elevation` parameter exists here
/// on purpose — dark-mode elevation is surface lightness, not a
/// shadow, and giving every call site a lever to raise one would
/// re-open that hole.
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
    final content = Padding(padding: padding, child: child);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: onTap == null
          ? content
          : InkWell(
              onTap: onTap,
              borderRadius: Radii.cardRadius,
              child: content,
            ),
    );
  }
}
