import 'package:flutter/material.dart';

/// Durations and curves from the brand guide (§7). An amount never
/// animates — [MoneyText] does not use any of these.
abstract final class Motion {
  static const Duration rowArrival = Duration(milliseconds: 180);
  static const Curve rowArrivalCurve = Curves.easeOut;

  /// How far a row rises while it fades in.
  static const double rowArrivalRise = 8;

  static const Duration sheetOpen = Duration(milliseconds: 240);
  static const Curve sheetOpenCurve = Curves.decelerate;

  static const Duration undoHold = Duration(milliseconds: 2000);
  static const Duration undoFade = Duration(milliseconds: 150);

  /// Returns [duration] unless the platform's reduce-motion setting is
  /// on, in which case it returns [Duration.zero] so the transition
  /// collapses to an instant cut instead of animating.
  ///
  /// Callers pass one of the durations above; nothing else in the app
  /// should branch on `MediaQuery.disableAnimations` directly.
  static Duration of(BuildContext context, Duration duration) {
    return MediaQuery.disableAnimationsOf(context) ? Duration.zero : duration;
  }
}
