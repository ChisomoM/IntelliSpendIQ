import 'package:flutter/material.dart';
import 'package:intellispendiq/design/tokens/typography.dart';

/// The IntelliSpendIQ wordmark: one word, three capitals, with `IQ`
/// carrying the accent colour and `IntelliSpend` in the text colour.
///
/// Per the brand guide, the colour split is dropped below 18px and the
/// whole mark sets in a single ink — at that size the two-tone reads as
/// a rendering artefact rather than a deliberate mark. Tracking is
/// −0.03em at every size.
///
/// The accent resolves to `colorScheme.primary`, which is violet600 on
/// light and cyan300 on dark. That satisfies the rule that cyan never
/// lands on a light surface without the caller having to know it.
class Wordmark extends StatelessWidget {
  const Wordmark({this.size = 20, super.key});

  final double size;

  /// Below this the mark sets in one ink, per the brand guide.
  static const double _colourSplitFloor = 18;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final base = AppTypography.screenTitle(color: colors.onSurface).copyWith(
      fontSize: size,
      height: 1.2,
      letterSpacing: -0.03 * size,
      fontWeight: FontWeight.w600,
    );

    if (size < _colourSplitFloor) {
      return Text('IntelliSpendIQ', style: base);
    }

    return Text.rich(
      TextSpan(
        style: base,
        children: [
          const TextSpan(text: 'IntelliSpend'),
          TextSpan(text: 'IQ', style: TextStyle(color: colors.primary)),
        ],
      ),
    );
  }
}
