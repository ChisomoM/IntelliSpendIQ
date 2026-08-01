import 'package:flutter/material.dart';
import 'package:intellispendiq/design/theme/capture_colors.dart';
import 'package:intellispendiq/design/tokens/typography.dart';

/// Where an entry came from — SMS, voice, or typed by hand.
///
/// Small and quiet on purpose. Per the brand guide's confidence rules,
/// a cleanly-parsed entry carries no badge at all — silence is the
/// signal — so this chip says only *how* something arrived, never how
/// sure the app is about it. Uncertainty is marked on the guessed
/// field itself, by [UncertainText].
class SourceChip extends StatelessWidget {
  const SourceChip(this.source, {super.key});

  final CaptureSource source;

  String get _label => switch (source) {
    CaptureSource.sms => 'SMS',
    CaptureSource.voice => 'VOICE',
    CaptureSource.manual => 'TYPED',
  };

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<CaptureColors>()!.forSource(
      source,
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: colors.fill,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              color: colors.dot,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Text(_label, style: AppTypography.chipOverline(color: colors.label)),
        ],
      ),
    );
  }
}

/// A single field the app guessed rather than read cleanly: rendered in
/// the review colour with a dotted underline.
///
/// Deliberately scoped to one field rather than a whole row — the
/// entry still counts toward the balance, and colouring the whole row
/// would read as "this entry is wrong" instead of "this one value is
/// a guess".
class UncertainText extends StatelessWidget {
  const UncertainText(this.text, {this.style, super.key});

  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final review = Theme.of(context).extension<CaptureColors>()!.uncertainField;

    return Text(
      text,
      style: (style ?? AppTypography.metadata()).copyWith(
        color: review,
        decoration: TextDecoration.underline,
        decorationStyle: TextDecorationStyle.dotted,
        decorationColor: review,
      ),
    );
  }
}
