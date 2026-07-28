import 'package:flutter/material.dart';

class SheetOption extends StatelessWidget {
  const SheetOption({
    required this.title,
    required this.icon,
    required this.onTap,
    this.dismiss = true,
    this.subtitle,
    this.color,
    super.key,
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final Color? color;
  final bool dismiss;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).colorScheme;
    var isDark = false;
    if (theme.brightness == Brightness.dark) {
      isDark = true;
    }
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      tileColor:
          isDark ? theme.surfaceContainerHighest : theme.surfaceContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      leading: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          shape: BoxShape.circle,
        ),
        padding: const EdgeInsets.all(10),
        child: Icon(
          icon,
          color: color ?? Theme.of(context).colorScheme.primary,
        ),
      ),
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle!) : null,
      onTap: () {
        if (dismiss) Navigator.pop(context);
        onTap.call();
      },
    );
  }
}
