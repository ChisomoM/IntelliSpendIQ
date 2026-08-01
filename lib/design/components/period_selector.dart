import 'package:flutter/material.dart';
import 'package:intellispendiq/design/components/app_icon.dart';
import 'package:intellispendiq/design/tokens/icons.dart';
import 'package:intellispendiq/design/tokens/spacing.dart';
import 'package:intellispendiq/design/tokens/typography.dart';

/// Chevron / label / chevron period navigation, shared by every screen
/// that walks a time range. Budgets and Reports each hand-built this
/// independently with different date semantics (budget cycle vs.
/// calendar month) — this widget only standardises the chrome; keeping
/// the underlying periods in sync is a Phase 7/8 concern, not this
/// component's.
class PeriodSelector extends StatelessWidget {
  const PeriodSelector({
    required this.label,
    required this.onPrevious,
    required this.onNext,
    super.key,
  });

  final String label;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          icon: AppIcon(AppIcons.chevronLeft),
          tooltip: 'Previous period',
          onPressed: onPrevious,
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.x1),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: AppTypography.rowTitle(color: colors.onSurface),
            ),
          ),
        ),
        IconButton(
          icon: AppIcon(AppIcons.chevronRight),
          tooltip: 'Next period',
          onPressed: onNext,
        ),
      ],
    );
  }
}
