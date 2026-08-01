import 'package:flutter/material.dart';
import 'package:intellispendiq/design/design.dart';
import 'package:intellispendiq/domain/models/proposed_action.dart';

/// A pending write the assistant proposed, shown until the user
/// confirms or dismisses it. Nothing behind this card has been saved.
class ProposedActionCard extends StatelessWidget {
  const ProposedActionCard({
    required this.action,
    required this.onConfirm,
    required this.onDismiss,
    required this.busy,
    super.key,
  });

  final ProposedAction action;
  final VoidCallback onConfirm;
  final VoidCallback onDismiss;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Space.gutter,
        vertical: Space.x1,
      ),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AppIcon(AppIcons.assistant, size: 18, color: colors.primary),
                const SizedBox(width: Space.x1),
                Expanded(
                  child: Text(
                    action.title,
                    style: AppTypography.rowTitle(color: colors.onSurface),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              action.subtitle,
              style: AppTypography.metadata(color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: Space.x1),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                AppButton.tertiary(
                  label: 'Dismiss',
                  onPressed: busy ? null : onDismiss,
                ),
                const SizedBox(width: Space.x1),
                AppButton.primary(
                  label: 'Confirm',
                  onPressed: busy ? null : onConfirm,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
