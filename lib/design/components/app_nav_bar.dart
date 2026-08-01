import 'package:flutter/material.dart';
import 'package:intellispendiq/design/components/app_icon.dart';
import 'package:intellispendiq/design/tokens/gradients.dart';
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
      color: Theme.of(context).brightness == Brightness.dark
          ? colors.surfaceContainerLow
          : colors.surface,
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
/// square per the brand guide, not a circle.
///
/// Three gestures: tap adds a transaction, **double-tap starts voice
/// capture**, long-press opens the full quick-add sheet.
///
/// One cost worth knowing: registering a double-tap means the single
/// tap cannot fire until the double-tap window has passed, so "add"
/// gains roughly 300ms before the sheet opens. That is the unavoidable
/// price of putting two actions on one target — the alternative is a
/// separate mic button, which is what the old two-FAB stack did and
/// what the centred FAB replaced.
class CenterFab extends StatelessWidget {
  const CenterFab({
    required this.onTap,
    this.onDoubleTap,
    this.onLongPress,
    super.key,
  });

  final VoidCallback onTap;

  /// Voice capture.
  final VoidCallback? onDoubleTap;

  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;

    // FloatingActionButton exposes neither double-tap nor long-press,
    // so the gestures are layered over it rather than replacing it with
    // a bare InkWell — the button keeps its ripple and semantics.
    return GestureDetector(
      onDoubleTap: onDoubleTap,
      onLongPress: onLongPress,
      child: Container(
        decoration: BoxDecoration(
          gradient: AppGradients.action(brightness),
          borderRadius: BorderRadius.circular(Radii.fab),
          boxShadow: AppShadows.raised(brightness),
        ),
        child: FloatingActionButton(
          onPressed: onTap,
          // The gradient is the fill; the button underneath must not
          // paint its own colour over it.
          backgroundColor: Colors.transparent,
          elevation: 0,
          focusElevation: 0,
          hoverElevation: 0,
          highlightElevation: 0,
          shape: Radii.fabShape,
          tooltip: 'Add · double-tap to speak · hold for more',
          child: AppIcon(AppIcons.add, color: theme.colorScheme.onPrimary),
        ),
      ),
    );
  }
}
