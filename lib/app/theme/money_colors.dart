import 'package:flutter/material.dart';
import 'package:intellispendiq/app/theme/tokens.dart';

/// Direction and confidence colours, resolved per brightness.
///
/// Exists as a [ThemeExtension] so that a widget reads
/// `context.money.outflow` and never branches on brightness itself —
/// there is exactly one place that knows which ramp is in play.
///
/// **Outflow is not an alert.** Spending is normal; the hue marks
/// direction. Over-budget and failed-sync borrow the same hue but always
/// pair it with words ("Over by K240"), because red/green colour
/// blindness affects roughly one in twelve Zambian men. Colour is never
/// the sole signal.
@immutable
class MoneyColors extends ThemeExtension<MoneyColors> {
  const MoneyColors({
    required this.inflow,
    required this.outflow,
    required this.review,
  });

  /// Money arriving.
  final Color inflow;

  /// Money leaving. Direction, not danger.
  final Color outflow;

  /// The field the app guessed. Only ever applied to the guessed field
  /// itself, never to a whole row.
  final Color review;

  static const light = MoneyColors(
    inflow: AppColors.inflowLight,
    outflow: AppColors.outflowLight,
    review: AppColors.reviewLight,
  );

  static const dark = MoneyColors(
    inflow: AppColors.inflowDark,
    outflow: AppColors.outflowDark,
    review: AppColors.reviewDark,
  );

  @override
  MoneyColors copyWith({Color? inflow, Color? outflow, Color? review}) {
    return MoneyColors(
      inflow: inflow ?? this.inflow,
      outflow: outflow ?? this.outflow,
      review: review ?? this.review,
    );
  }

  @override
  MoneyColors lerp(MoneyColors? other, double t) {
    if (other == null) return this;
    return MoneyColors(
      inflow: Color.lerp(inflow, other.inflow, t)!,
      outflow: Color.lerp(outflow, other.outflow, t)!,
      review: Color.lerp(review, other.review, t)!,
    );
  }
}

extension MoneyColorsX on BuildContext {
  /// The money palette for the current brightness.
  MoneyColors get money => Theme.of(this).extension<MoneyColors>()!;
}
