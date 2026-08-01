import 'package:flutter/material.dart';
import 'package:intellispendiq/core/money.dart';
import 'package:intellispendiq/design/theme/money_colors.dart';
import 'package:intellispendiq/design/tokens/typography.dart';

/// Which type-scale role a [MoneyText] renders at.
enum MoneySize {
  /// 34/38 mono — a summary card's headline figure.
  display,

  /// 16/22 mono — a ledger row's trailing amount.
  row,

  /// 13/18 mono — a small figure inside a caption or a chip.
  meta,
}

/// Renders one amount the way the ledger does everywhere: `K1,250.00`,
/// `−K89.00`, `+K3,000.00`, always tabular. This is a widget rather
/// than a string helper because sign colour and tabular alignment are
/// rendering concerns, not formatting ones — colour comes from
/// [MoneyColors] and this widget never branches on `Brightness` itself.
///
/// An amount never animates (brand guide §7) — this widget has no
/// `AnimatedSwitcher` and must not grow one.
class MoneyText extends StatelessWidget {
  /// Unsigned: `K1,250.00`. Use for a figure with no direction of its
  /// own — "Budgeted: K50.00", a total, a balance.
  const MoneyText(
    this.amountMinor, {
    this.size = MoneySize.row,
    this.color,
    super.key,
  }) : isInflow = null;

  /// Signed and coloured by direction: `+K3,000.00` in [MoneyColors.inflow],
  /// `−K89.00` in [MoneyColors.outflow]. [amountMinor] is the absolute
  /// amount — direction comes from [isInflow], matching how the
  /// domain model stores transactions.
  const MoneyText.signed(
    this.amountMinor, {
    required bool this.isInflow,
    this.size = MoneySize.row,
    super.key,
  }) : color = null;

  final int amountMinor;
  final bool? isInflow;
  final MoneySize size;

  /// Overrides the resolved colour. Leave null for the normal
  /// unsigned/signed behaviour above.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final moneyColors = Theme.of(context).extension<MoneyColors>();
    final resolvedColor = color ??
        (isInflow == null
            ? null
            : (isInflow! ? moneyColors?.inflow : moneyColors?.outflow));

    final style = switch (size) {
      MoneySize.display => AppTypography.balanceDisplay(color: resolvedColor),
      MoneySize.row => AppTypography.rowAmount(color: resolvedColor),
      MoneySize.meta => AppTypography.metaAmount(color: resolvedColor),
    };

    final text = isInflow == null
        ? Money.display(amountMinor)
        : Money.displaySigned(amountMinor, isInflow: isInflow!);

    return Text(text, style: style);
  }
}

/// Compact form for chart axes and headlines: `K12.5k`. Never used in
/// the ledger itself, where ngwee must show.
class CompactMoneyText extends StatelessWidget {
  const CompactMoneyText(this.amountMinor, {this.color, super.key});

  final int amountMinor;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Text(
      Money.displayCompact(amountMinor),
      style: AppTypography.metadata(color: color),
    );
  }
}
