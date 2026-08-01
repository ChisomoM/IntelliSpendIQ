import 'package:flutter/material.dart';
import 'package:intellispendiq/design/tokens/spacing.dart';

/// The one bottom-sheet shape in the app: a drag handle and consistent
/// padding. The modal route's own transition already respects
/// `MediaQuery.disableAnimations`, so no bespoke animation is driven
/// here — see `Motion.sheetOpen` for the intended feel (240ms,
/// decelerate) that transition approximates.
///
/// Replaces the six independent `showModalBottomSheet` call sites that
/// each picked their own padding and, in most cases, no drag handle.
abstract final class AppSheet {
  static Future<T?> show<T>(
    BuildContext context, {
    required WidgetBuilder builder,
    bool isScrollControlled = true,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: isScrollControlled,
      useSafeArea: true,
      builder: (context) => _AppSheetChrome(child: builder(context)),
    );
  }
}

class _AppSheetChrome extends StatelessWidget {
  const _AppSheetChrome({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: Space.x1),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Flexible(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                Space.gutter,
                Space.x2,
                Space.gutter,
                Space.x2,
              ),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}
