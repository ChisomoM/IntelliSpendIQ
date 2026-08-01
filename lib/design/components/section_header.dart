import 'package:flutter/material.dart';
import 'package:intellispendiq/design/tokens/spacing.dart';
import 'package:intellispendiq/design/tokens/typography.dart';

/// A section label within a screen, with an optional subtitle and an
/// optional trailing action ("See all", "Edit"). Replaces the private
/// `_SectionHeader` copies that existed independently in Settings and
/// Review.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    required this.title,
    this.subtitle,
    this.action,
    this.onActionTap,
    super.key,
  });

  final String title;
  final String? subtitle;
  final String? action;
  final VoidCallback? onActionTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Space.x1),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.sectionHeader(color: colors.onSurface),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    style: AppTypography.metadata(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (action != null)
            TextButton(
              onPressed: onActionTap,
              child: Text(action!),
            ),
        ],
      ),
    );
  }
}
