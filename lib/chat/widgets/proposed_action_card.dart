import 'package:flutter/material.dart';
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
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.surfaceContainerHigh,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(action.title, style: theme.textTheme.titleSmall),
            const SizedBox(height: 2),
            Text(action.subtitle, style: theme.textTheme.bodySmall),
            const SizedBox(height: 8),
            OverflowBar(
              alignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: busy ? null : onDismiss,
                  child: const Text('Dismiss'),
                ),
                FilledButton(
                  onPressed: busy ? null : onConfirm,
                  child: const Text('Confirm'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
