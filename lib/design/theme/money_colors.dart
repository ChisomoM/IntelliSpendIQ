import 'package:flutter/material.dart';
import 'package:intellispendiq/design/tokens/colors.dart';

/// Semantic colour for money direction and uncertainty.
///
/// Widgets read `Theme.of(context).extension<MoneyColors>()!` and never
/// branch on `Theme.of(context).brightness` themselves — dark mode is
/// not a brightness flip of light mode here (`outflowD` is a salmon,
/// not a darkened red), so the extension is the only place that
/// distinction is allowed to live.
///
/// Per the brand guide: outflow is not an alert. Spending is normal;
/// the hue marks direction, not danger. Over-budget and failed-sync
/// states reuse [outflow] but must always pair it with words — colour
/// is never the sole signal.
class MoneyColors extends ThemeExtension<MoneyColors> {
  const MoneyColors({
    required this.inflow,
    required this.outflow,
    required this.review,
  });

  static const light = MoneyColors(
    inflow: AppColors.inflow,
    outflow: AppColors.outflow,
    review: AppColors.review,
  );

  static const dark = MoneyColors(
    inflow: AppColors.inflowD,
    outflow: AppColors.outflowD,
    review: AppColors.reviewD,
  );

  /// Money received.
  final Color inflow;

  /// Money spent. Direction, not alert.
  final Color outflow;

  /// A field the app guessed rather than parsed with confidence.
  final Color review;

  @override
  MoneyColors copyWith({Color? inflow, Color? outflow, Color? review}) {
    return MoneyColors(
      inflow: inflow ?? this.inflow,
      outflow: outflow ?? this.outflow,
      review: review ?? this.review,
    );
  }

  @override
  MoneyColors lerp(ThemeExtension<MoneyColors>? other, double t) {
    if (other is! MoneyColors) return this;
    return MoneyColors(
      inflow: Color.lerp(inflow, other.inflow, t)!,
      outflow: Color.lerp(outflow, other.outflow, t)!,
      review: Color.lerp(review, other.review, t)!,
    );
  }
}
