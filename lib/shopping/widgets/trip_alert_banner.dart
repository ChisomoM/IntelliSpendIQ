import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intellispendiq/core/money.dart';
import 'package:intellispendiq/design/design.dart';
import 'package:intellispendiq/domain/services/shopping_trip_calculator.dart';
import 'package:intellispendiq/shopping/cubit/cubit.dart';

/// Tells the shopper in words when a category nears or passes its
/// limit. It sits above the add bar rather than floating as a snackbar,
/// because a snackbar would cover the checkout button for the seconds
/// it is up.
class TripAlertBanner extends StatefulWidget {
  const TripAlertBanner({super.key});

  @override
  State<TripAlertBanner> createState() => _TripAlertBannerState();
}

class _TripAlertBannerState extends State<TripAlertBanner> {
  static const _visibleFor = Duration(seconds: 8);

  TripAlert? _current;
  String _message = '';
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _show(ShoppingTripState state, TripAlert alert) {
    final name = state.categoryName(alert.categoryId);
    final over = alert.severity == TripSeverity.over;
    unawaited(
      over ? HapticFeedback.heavyImpact() : HapticFeedback.lightImpact(),
    );
    _timer?.cancel();
    _timer = Timer(_visibleFor, _dismiss);
    setState(() {
      _current = alert;
      _message = over
          ? '$name is ${Money.display(-alert.leftMinor)} over its budget'
          : '$name is nearly at its limit, ${Money.display(alert.leftMinor)} left';
    });
  }

  void _dismiss() {
    _timer?.cancel();
    if (mounted) setState(() => _current = null);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final money = Theme.of(context).extension<MoneyColors>()!;
    final review = Theme.of(context).extension<CaptureColors>()!.uncertainField;

    return BlocListener<ShoppingTripCubit, ShoppingTripState>(
      listenWhen: (previous, current) =>
          current.alert != null && previous.alert != current.alert,
      listener: (context, state) => _show(state, state.alert!),
      child: AnimatedSize(
        duration: Motion.of(context, Motion.sheetOpen),
        alignment: Alignment.bottomCenter,
        child: _current == null
            ? const SizedBox(width: double.infinity)
            : _banner(
                colors: colors,
                tone: _current!.severity == TripSeverity.over
                    ? money.outflow
                    : review,
              ),
      ),
    );
  }

  Widget _banner({required ColorScheme colors, required Color tone}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Space.gutter,
        Space.x1,
        Space.gutter,
        0,
      ),
      child: Material(
        color: tone.withValues(alpha: 0.12),
        borderRadius: Radii.cardRadius,
        child: Padding(
          padding: const EdgeInsets.only(left: Space.x2),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _message,
                  style: AppTypography.rowTitle(color: colors.onSurface),
                ),
              ),
              IconButton(
                tooltip: 'Dismiss',
                onPressed: _dismiss,
                icon: AppIcon(
                  AppIcons.close,
                  size: 18,
                  color: colors.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
