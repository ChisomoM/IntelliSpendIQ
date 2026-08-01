import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

/// Thin wrapper over [HugeIcon] with an `Icon`-shaped default: size 24,
/// colour inherited from `IconTheme` when not given explicitly.
///
/// Every icon in the app renders through this widget rather than
/// through `HugeIcon` directly, so there is one place to change if the
/// rendering approach (size defaults, theming) ever needs to move.
class AppIcon extends StatelessWidget {
  const AppIcon(this.icon, {this.size, this.color, super.key});

  /// A constant from `AppIcons` or `CategoryIcons`.
  final List<List<dynamic>> icon;
  final double? size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final iconTheme = IconTheme.of(context);
    return HugeIcon(
      icon: icon,
      size: size ?? iconTheme.size ?? 24,
      color: color ?? iconTheme.color ?? Theme.of(context).colorScheme.onSurface,
    );
  }
}
