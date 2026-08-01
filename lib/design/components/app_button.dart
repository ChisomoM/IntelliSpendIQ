import 'package:flutter/material.dart';

/// Three button weights, one import. `AppTheme` already themes
/// `FilledButton`/`OutlinedButton`/`TextButton` consistently (48dp
/// minimum, stadium shape); this widget exists so call sites reach for
/// one semantic name instead of picking a raw Material widget by hand.
enum _AppButtonKind { primary, secondary, tertiary }

class AppButton extends StatelessWidget {
  const AppButton.primary({
    required this.label,
    required this.onPressed,
    this.icon,
    super.key,
  }) : _kind = _AppButtonKind.primary;

  const AppButton.secondary({
    required this.label,
    required this.onPressed,
    this.icon,
    super.key,
  }) : _kind = _AppButtonKind.secondary;

  const AppButton.tertiary({
    required this.label,
    required this.onPressed,
    this.icon,
    super.key,
  }) : _kind = _AppButtonKind.tertiary;

  final String label;
  final VoidCallback? onPressed;
  final Widget? icon;
  final _AppButtonKind _kind;

  @override
  Widget build(BuildContext context) {
    final child = Text(label);

    return switch (_kind) {
      _AppButtonKind.primary => icon == null
          ? FilledButton(onPressed: onPressed, child: child)
          : FilledButton.icon(onPressed: onPressed, icon: icon, label: child),
      _AppButtonKind.secondary => icon == null
          ? OutlinedButton(onPressed: onPressed, child: child)
          : OutlinedButton.icon(
              onPressed: onPressed,
              icon: icon,
              label: child,
            ),
      _AppButtonKind.tertiary => icon == null
          ? TextButton(onPressed: onPressed, child: child)
          : TextButton.icon(onPressed: onPressed, icon: icon, label: child),
    };
  }
}
