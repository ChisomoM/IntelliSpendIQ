import 'package:flutter/material.dart';
import 'package:intellispendiq/design/components/app_icon.dart';
import 'package:intellispendiq/design/tokens/spacing.dart';
import 'package:intellispendiq/design/tokens/typography.dart';

/// One shared shape for "nothing here yet": icon, heading, message,
/// optional primary action. Replaces the four bespoke empty-state
/// widgets that grew independently (Activity, Budgets, Review) plus
/// Reports' bare centred `Text`.
class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  /// A `HugeIcons.strokeRounded*` constant.
  final List<List<dynamic>> icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Space.x4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppIcon(icon, size: 40, color: colors.onSurfaceVariant),
            const SizedBox(height: Space.x2),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTypography.sectionHeader(color: colors.onSurface),
            ),
            if (message != null) ...[
              const SizedBox(height: Space.x1),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: AppTypography.body(color: colors.onSurfaceVariant),
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: Space.x2),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
