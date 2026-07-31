import 'package:flutter/material.dart';
import 'package:intellispendiq/app/theme/tokens.dart';
import 'package:intellispendiq/app/theme/typography.dart';
import 'package:intellispendiq/core/app_section.dart';

/// The bottom navigation bar, with a gap in the middle for the capture
/// FAB to dock into.
///
/// Hand-built rather than a [NavigationBar] because that widget owns its
/// own layout and has nowhere to put the notch — and because the label
/// style here is the tracked mono overline from the type scale, which
/// Material's pill indicator fights with.
class AppBottomBar extends StatelessWidget {
  const AppBottomBar({
    required this.currentIndex,
    required this.onSelected,
    super.key,
  });

  final int currentIndex;
  final ValueChanged<int> onSelected;

  /// Wide enough to clear a 56dp FAB plus breathing room on each side.
  static const double fabGap = 76;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final left = AppSection.tabs.take(2).toList();
    final right = AppSection.tabs.skip(2).toList();

    return DecoratedBox(
      decoration: BoxDecoration(
        color: isDark ? AppColors.night800 : AppColors.paper,
        border: Border(
          top: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 62,
          child: Row(
            children: [
              for (final section in left) _slot(section),
              const SizedBox(width: fabGap),
              for (final section in right) _slot(section),
            ],
          ),
        ),
      ),
    );
  }

  Widget _slot(AppSection section) {
    return Expanded(
      child: _NavSlot(
        section: section,
        isSelected: section.tabIndex == currentIndex,
        onTap: () => onSelected(section.tabIndex),
      ),
    );
  }
}

class _NavSlot extends StatelessWidget {
  const _NavSlot({
    required this.section,
    required this.isSelected,
    required this.onTap,
  });

  final AppSection section;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Violet in light mode, cyan in dark — the scheme's primary already
    // resolves to the right one, but the active marker uses `secondary`
    // so that cyan stays reserved for the single loudest thing on a
    // dark screen, which is the FAB.
    final color = isSelected ? scheme.secondary : scheme.onSurfaceVariant;

    return Semantics(
      selected: isSelected,
      button: true,
      child: InkResponse(
        onTap: onTap,
        radius: 36,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(_icon, size: 24, color: color),
            const SizedBox(height: Space.xs),
            Text(
              section.label.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.overline.copyWith(color: color),
            ),
          ],
        ),
      ),
    );
  }

  IconData get _icon => switch (section) {
    AppSection.home => isSelected ? Icons.home : Icons.home_outlined,
    AppSection.activity =>
      isSelected ? Icons.receipt_long : Icons.receipt_long_outlined,
    AppSection.budgets => isSelected ? Icons.savings : Icons.savings_outlined,
    AppSection.reports => isSelected ? Icons.insights : Icons.insights_outlined,
    // Not nav tabs — see AppSection.tabs.
    AppSection.review ||
    AppSection.chat ||
    AppSection.settings => Icons.circle_outlined,
  };
}
