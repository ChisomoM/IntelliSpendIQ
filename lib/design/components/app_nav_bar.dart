import 'package:flutter/material.dart';
import 'package:intellispendiq/design/components/app_icon.dart';
import 'package:intellispendiq/design/tokens/icons.dart';
import 'package:intellispendiq/design/tokens/radii.dart';
import 'package:intellispendiq/design/tokens/spacing.dart';
import 'package:intellispendiq/design/tokens/typography.dart';

/// One destination in [AppNavBar].
class AppNavDestination {
  const AppNavDestination({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    this.badgeCount = 0,
  });

  final List<List<dynamic>> icon;
  final List<List<dynamic>> selectedIcon;
  final String label;
  final int badgeCount;
}

/// The bottom nav bar, built to dock a centred FAB in its notch (see
/// [CenterFab]) rather than the plain `NavigationBar` the app used
/// before — Material's `NavigationBar` has no notch support, and the
/// primary action needs to live in the bar itself so it is reachable
/// from every tab, not just Activity.
class AppNavBar extends StatelessWidget {
  const AppNavBar({
    required this.destinations,
    required this.selectedIndex,
    required this.onDestinationSelected,
    super.key,
  });

  final List<AppNavDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final half = (destinations.length / 2).ceil();
    final left = destinations.take(half).toList();
    final right = destinations.skip(half).toList();

    Widget item(AppNavDestination destination, int index) {
      final selected = index == selectedIndex;
      final color = selected ? colors.primary : colors.onSurfaceVariant;

      return Expanded(
        child: InkWell(
          onTap: () => onDestinationSelected(index),
          child: SizedBox(
            height: Space.x6,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Badge(
                  isLabelVisible: destination.badgeCount > 0,
                  label: Text('${destination.badgeCount}'),
                  child: AppIcon(
                    selected ? destination.selectedIcon : destination.icon,
                    color: color,
                    size: 24,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  destination.label,
                  style: AppTypography.metadata(color: color),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return BottomAppBar(
      height: Space.x6 + Space.x1,
      padding: EdgeInsets.zero,
      color: colors.surfaceContainerLow,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: const CircularNotchedRectangle(),
      notchMargin: Space.x1 / 2,
      child: Row(
        children: [
          for (final (index, destination) in left.indexed)
            item(destination, index),
          const SizedBox(width: Space.x5),
          for (final (offset, destination) in right.indexed)
            item(destination, half + offset),
        ],
      ),
    );
  }
}

/// The primary action, docked centre in [AppNavBar]'s notch. A rounded
/// square per the brand guide, not a circle — `Radii.fabShape` — so it
/// sits slightly proud of the notch's circular cutout rather than
/// filling it exactly; an accepted trade for staying on-brand rather
/// than bending the shape to fit Material's notch geometry.
///
/// Tap opens the add-transaction flow. Long-press opens a short sheet
/// with the other quick actions, so voice capture and the assistant
/// stay one gesture away from every tab instead of Activity only.
class CenterFab extends StatelessWidget {
  const CenterFab({required this.onTap, this.onLongPress, super.key});

  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    // FloatingActionButton has no onLongPress of its own — the long
    // press for the quick-add sheet is layered on with a
    // GestureDetector rather than swapping in a plain InkWell, so the
    // button keeps its normal ripple, elevation and semantics.
    return GestureDetector(
      onLongPress: onLongPress,
      child: FloatingActionButton(
        onPressed: onTap,
        shape: Radii.fabShape,
        tooltip: 'Add transaction — hold for more',
        child: AppIcon(
          AppIcons.add,
          color: Theme.of(context).colorScheme.onPrimary,
        ),
      ),
    );
  }
}
