import 'package:flutter/material.dart';
import 'package:intellispendiq/app/theme/money_colors.dart';
import 'package:intellispendiq/app/theme/tokens.dart';
import 'package:intellispendiq/app/theme/typography.dart';
import 'package:intellispendiq/domain/models/enums.dart';

/// Names where a transaction came from.
///
/// Capture is the product, so the source is stated on the row rather
/// than implied by an icon: SMS in ink, voice in violet, manual with a
/// hollow dot because the user *is* the source of truth and there is
/// nothing to be confident or unconfident about.
class SourceChip extends StatelessWidget {
  const SourceChip(this.source, {super.key});

  final TxSource source;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isVoice = source == TxSource.voice;

    // Dark mode collapses the two fills into one surface and carries the
    // distinction in the label colour instead — a violet fill on
    // near-black would be louder than the row it labels.
    final background = isDark
        ? AppColors.night700
        : (isVoice ? AppColors.violet100 : AppColors.ink100);
    final foreground = isDark
        ? (isVoice ? AppColors.violet300 : AppColors.nightText2)
        : (isVoice ? AppColors.violet700 : AppColors.ink700);
    final dot = switch (source) {
      TxSource.voice => isDark ? AppColors.violet300 : AppColors.violet600,
      TxSource.manual => isDark ? AppColors.nightLineStrong : AppColors.ink300,
      TxSource.sms ||
      TxSource.notification => isDark ? AppColors.nightText2 : AppColors.ink500,
    };

    return _ChipShell(
      background: background,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
          ),
          const SizedBox(width: Space.sm),
          Text(_label, style: AppText.overline.copyWith(color: foreground)),
        ],
      ),
    );
  }

  String get _label => switch (source) {
    TxSource.sms => 'SMS',
    TxSource.notification => 'ALERT',
    TxSource.voice => 'VOICE',
    TxSource.manual => 'MANUAL',
  };
}

/// States a transaction's confidence in words.
///
/// A **certain** entry gets no chip at all — silence is the signal, and
/// a row that shouts "confirmed" teaches the user to ignore chips. Only
/// the states that need a person render anything.
class StatusChip extends StatelessWidget {
  const StatusChip(this.status, {super.key});

  final TxStatus status;

  @override
  Widget build(BuildContext context) {
    if (status == TxStatus.confirmed) return const SizedBox.shrink();
    final money = context.money;

    return _ChipShell(
      background: money.review.withValues(alpha: 0.12),
      child: Text(
        _label,
        style: AppText.overline.copyWith(color: money.review),
      ),
    );
  }

  String get _label => switch (status) {
    TxStatus.duplicateSuspect => 'MAYBE TWICE',
    TxStatus.planned => 'PLANNED',
    TxStatus.needsReview => 'NEEDS YOU',
    TxStatus.confirmed => '',
  };
}

/// A small uppercase label above a value — the only place 11px type is
/// allowed, and only ever as a label, never as a sentence.
class Overline extends StatelessWidget {
  const Overline(this.text, {this.color, super.key});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: AppText.overline.copyWith(
        color: color ?? Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}

/// Marks a single field the app guessed.
///
/// Wraps **only** the guessed field — never a whole row — in the review
/// colour with a dotted underline. The row itself stays normal and keeps
/// counting toward the balance, because the app is confident about the
/// amount even when it is unsure about the category.
class UncertainField extends StatelessWidget {
  const UncertainField(this.text, {this.style, super.key});

  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final money = context.money;
    return Text(
      text,
      style: (style ?? AppText.rowTitle).copyWith(
        color: money.review,
        decoration: TextDecoration.underline,
        decorationStyle: TextDecorationStyle.dotted,
        decorationColor: money.review,
      ),
      semanticsLabel: '$text, not certain',
    );
  }
}

class _ChipShell extends StatelessWidget {
  const _ChipShell({required this.background, required this.child});

  final Color background;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Space.sm,
        vertical: Space.xs,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(Radii.chip),
      ),
      child: child,
    );
  }
}
