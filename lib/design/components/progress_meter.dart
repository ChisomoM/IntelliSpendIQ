import 'package:flutter/material.dart';
import 'package:intellispendiq/design/theme/money_colors.dart';
import 'package:intellispendiq/design/tokens/colors.dart';

/// A spend-against-plan bar.
///
/// Deliberately colour-only: the words that go with it are the
/// caller's job, because the brand guide requires every colour-carrying
/// state to also carry a word ("K240 over, 9 days left"), and a widget
/// that rendered its own label would let a call site skip that.
///
/// Over-plan uses [MoneyColors.outflow] — the same hue ordinary
/// spending uses, because outflow marks direction, not alarm. It is
/// the accompanying words, not the colour, that say something is
/// wrong.
class ProgressMeter extends StatelessWidget {
  const ProgressMeter({
    required this.value,
    this.isOver = false,
    this.onDarkSurface = false,
    this.height = 8,
    this.fillColor,
    super.key,
  });

  /// Overrides the fill when the bar belongs to something that already
  /// has a colour — a category envelope wears its own hue, so a screen
  /// of envelopes reads as a set rather than a column of identical
  /// violet bars. Ignored when [isOver], because overspend outranks
  /// identity.
  final Color? fillColor;

  /// Fraction spent, 0..1. Values above 1 are clamped — [isOver]
  /// carries the overspend, not a bar longer than its track.
  final double value;
  final bool isOver;

  /// Set when the meter sits on a dark card in either theme, so the
  /// track and fill stay legible there. Light-surface rules forbid
  /// violet300/cyan300 fills; a dark card is exempt because the
  /// surface itself is dark.
  ///
  /// This also switches the over-plan fill to the dark-mode outflow,
  /// because [MoneyColors] is keyed on the *theme's* brightness and a
  /// dark card inside a light theme is the one case it cannot
  /// express — light mode's outflow is a dark red that all but
  /// disappears against ink900.
  final bool onDarkSurface;
  final double height;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final money = Theme.of(context).extension<MoneyColors>()!;

    // violet300 rather than `colors.secondary` on a dark card: in the
    // light theme secondary is violet700, which is as dark as the card
    // under it. violet300 is legal here for the same reason outflowD
    // is — the surface is dark in both themes.
    final overFill = onDarkSurface ? AppColors.outflowD : money.outflow;
    final fill = isOver
        ? overFill
        : (fillColor ??
              (onDarkSurface ? AppColors.violet300 : colors.primary));
    final track = onDarkSurface
        ? Colors.white.withValues(alpha: 0.16)
        : colors.surfaceContainerHigh;

    return ClipRRect(
      borderRadius: BorderRadius.circular(height / 2),
      child: LinearProgressIndicator(
        value: value.clamp(0.0, 1.0),
        minHeight: height,
        backgroundColor: track,
        valueColor: AlwaysStoppedAnimation<Color>(fill),
      ),
    );
  }
}
