import 'package:flutter/material.dart';
import 'package:intellispendiq/app/theme/money_colors.dart';
import 'package:intellispendiq/app/theme/tokens.dart';
import 'package:intellispendiq/app/theme/typography.dart';
import 'package:intellispendiq/ui/chips.dart';
import 'package:intellispendiq/ui/money_text.dart';

/// Progress against a plan, with the state always written out.
///
/// [caption] is required, not optional, and that is the point: roughly
/// one in twelve Zambian men has red/green colour blindness, so a bar
/// that turns red without also saying "Over by K240" has communicated
/// nothing to them. Colour is never the sole signal, and making the
/// words mandatory is how that rule is enforced rather than remembered.
class ProgressMeter extends StatelessWidget {
  const ProgressMeter({
    required this.value,
    required this.caption,
    this.label,
    this.isOver = false,
    super.key,
  });

  /// 0..1. Clamped, so an over-budget meter still reads as full rather
  /// than overflowing its track.
  final double value;

  /// The state, in words. Required — see the class doc.
  final String caption;

  /// An optional name above the bar.
  final String? label;

  /// Drives the colour. The caption still has to say so in words.
  final bool isOver;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final money = context.money;
    final barColor = isOver ? money.outflow : scheme.secondary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: AppText.rowTitle.copyWith(color: scheme.onSurface),
          ),
          const SizedBox(height: Space.sm),
        ],
        ClipRRect(
          borderRadius: BorderRadius.circular(Radii.chip),
          child: LinearProgressIndicator(
            value: value.clamp(0.0, 1.0),
            minHeight: 8,
            backgroundColor: scheme.surfaceContainerHigh,
            valueColor: AlwaysStoppedAnimation(barColor),
          ),
        ),
        const SizedBox(height: Space.sm),
        Text(
          caption,
          style: AppText.metadata.copyWith(
            color: isOver ? money.outflow : scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// An overline label above a figure, with optional supporting words.
class StatTile extends StatelessWidget {
  const StatTile({
    required this.label,
    required this.amountMinor,
    this.caption,
    this.tone = MoneyTone.neutral,
    this.size = MoneySize.large,
    this.compact = false,
    super.key,
  });

  final String label;
  final int amountMinor;
  final String? caption;
  final MoneyTone tone;
  final MoneySize size;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Overline(label),
        const SizedBox(height: Space.xs),
        MoneyText(amountMinor, tone: tone, size: size, compact: compact),
        if (caption != null) ...[
          const SizedBox(height: Space.xs),
          Text(
            caption!,
            style: AppText.metadata.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ],
    );
  }
}
