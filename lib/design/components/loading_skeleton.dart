import 'package:flutter/material.dart';
import 'package:intellispendiq/design/tokens/radii.dart';

/// A pulsing placeholder block, used in place of a bare
/// `CircularProgressIndicator` when the eventual content has a known
/// shape (a card, a row, a figure). Honours reduce-motion: the pulse
/// collapses to a static mid-opacity block rather than animating.
class LoadingSkeleton extends StatefulWidget {
  const LoadingSkeleton({
    this.width,
    this.height = 16,
    this.borderRadius = Radii.cardRadius,
    super.key,
  });

  final double? width;
  final double height;
  final BorderRadius borderRadius;

  @override
  State<LoadingSkeleton> createState() => _LoadingSkeletonState();
}

class _LoadingSkeletonState extends State<LoadingSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).colorScheme.surfaceContainerHigh;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    Widget block(double opacity) => Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: base.withValues(alpha: opacity),
        borderRadius: widget.borderRadius,
      ),
    );

    if (reduceMotion) return block(0.7);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => block(0.5 + _controller.value * 0.3),
    );
  }
}

/// A stack of [LoadingSkeleton] rows shaped like a card list, for
/// screens that load a list of similar items.
class LoadingSkeletonList extends StatelessWidget {
  const LoadingSkeletonList({this.rowCount = 4, super.key});

  final int rowCount;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < rowCount; i++)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 6),
            child: LoadingSkeleton(width: double.infinity, height: 56),
          ),
      ],
    );
  }
}
