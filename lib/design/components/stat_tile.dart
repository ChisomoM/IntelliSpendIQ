import 'package:flutter/material.dart';
import 'package:intellispendiq/design/components/app_card.dart';
import 'package:intellispendiq/design/tokens/typography.dart';

/// A small labelled figure in a card — used in rows of two or three to
/// break a headline number into its parts (budgeted / spent /
/// remaining).
///
/// Takes [value] as a widget rather than a string so callers pass a
/// `MoneyText` and keep tabular alignment; a plain `Text` would lose
/// it.
class StatTile extends StatelessWidget {
  const StatTile({required this.label, required this.value, super.key});

  final String label;
  final Widget value;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return AppCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label.toUpperCase(),
            style: AppTypography.chipOverline(color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: 6),
          value,
        ],
      ),
    );
  }
}
