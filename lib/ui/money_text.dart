import 'package:flutter/material.dart';
import 'package:intellispendiq/app/theme/money_colors.dart';
import 'package:intellispendiq/app/theme/typography.dart';
import 'package:intellispendiq/core/money.dart';

/// Which direction an amount is moving, which is the only thing that
/// decides its colour.
enum MoneyTone {
  /// Balances, totals, transfers between the user's own accounts —
  /// anything where "in" or "out" is not the point.
  neutral,

  /// Money arriving.
  inflow,

  /// Money leaving. Direction, not danger.
  outflow,
}

/// Where the amount sits in the hierarchy.
enum MoneySize {
  /// The one big number on a screen. Mono 34.
  balance,

  /// A stat tile or a section total. Mono 22.
  large,

  /// A ledger row. Mono 16.
  row,

  /// A dense secondary position. Mono 13.
  small,
}

/// The single amount renderer.
///
/// No screen formats money itself — sign, colour, face and compaction
/// all live here, so a change to the money rules is a change to one
/// widget rather than to forty call sites. Every size is IBM Plex Mono,
/// which is what makes a column of amounts align on the decimal.
///
/// An amount **never animates**, so this is deliberately a plain
/// [StatelessWidget] with no implicit animation of its own.
class MoneyText extends StatelessWidget {
  const MoneyText(
    this.amountMinor, {
    this.tone = MoneyTone.neutral,
    this.size = MoneySize.row,
    this.showSign = false,
    this.compact = false,
    this.currency,
    this.uncertain = false,
    this.color,
    super.key,
  });

  /// A balance or total: neutral tone, display size.
  const MoneyText.balance(
    this.amountMinor, {
    this.currency,
    this.color,
    super.key,
  }) : tone = MoneyTone.neutral,
       size = MoneySize.balance,
       showSign = false,
       compact = false,
       uncertain = false;

  final int amountMinor;
  final MoneyTone tone;
  final MoneySize size;

  /// Prefix `+` or `−` per [tone]. Ignored when the tone is neutral,
  /// since there is no direction to state.
  final bool showSign;

  /// Round to `K12.5k` and drop the ngwee — for chart axes and headline
  /// figures only, never in the ledger.
  final bool compact;

  final String? currency;

  /// The app guessed this figure. Renders in the review colour with a
  /// dotted underline, per the confidence rules. Only ever set on the
  /// field that was actually guessed.
  final bool uncertain;

  /// Overrides the tone colour — for an amount on a coloured surface,
  /// where the ramp would not have the contrast it was picked for.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final money = context.money;
    final scheme = Theme.of(context).colorScheme;

    final resolved =
        color ??
        (uncertain
            ? money.review
            : switch (tone) {
                MoneyTone.neutral => scheme.onSurface,
                MoneyTone.inflow => money.inflow,
                MoneyTone.outflow => money.outflow,
              });

    final base = switch (size) {
      MoneySize.balance => AppText.balance,
      MoneySize.large => AppText.amountLarge,
      MoneySize.row => AppText.amount,
      MoneySize.small => AppText.amountSmall,
    };

    return Text(
      _text,
      style: base.copyWith(
        color: resolved,
        decoration: uncertain ? TextDecoration.underline : null,
        decorationStyle: uncertain ? TextDecorationStyle.dotted : null,
        decorationColor: uncertain ? money.review : null,
      ),
      // Amounts never truncate — they wrap instead, so a large font
      // scale cannot hide a digit.
      softWrap: true,
      semanticsLabel: _semanticsLabel,
    );
  }

  String get _text {
    if (compact) return Money.compact(amountMinor, currency: currency);
    if (showSign && tone != MoneyTone.neutral) {
      return Money.signed(
        amountMinor,
        isInflow: tone == MoneyTone.inflow,
        currency: currency,
      );
    }
    return Money.format(amountMinor, currency: currency);
  }

  /// Screen readers get the spoken currency and the direction as a word,
  /// because a `−` glyph and a colour are both invisible to them.
  String get _semanticsLabel {
    final amount = Money.withIsoCode(
      amountMinor.abs(),
      currency: currency ?? Money.isoCode,
    );
    final direction = switch (tone) {
      MoneyTone.inflow => 'in, ',
      MoneyTone.outflow => 'out, ',
      MoneyTone.neutral => '',
    };
    final guessed = uncertain ? ', not certain' : '';
    return '$direction$amount$guessed';
  }
}
