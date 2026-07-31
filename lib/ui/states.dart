import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intellispendiq/app/theme/tokens.dart';
import 'package:intellispendiq/app/theme/typography.dart';

/// Nothing here yet — said in plain words, with the action that would
/// change that, if there is one.
class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(Space.xxxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: scheme.outline),
            const SizedBox(height: Space.xl),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppText.sectionHeader.copyWith(color: scheme.onSurface),
            ),
            const SizedBox(height: Space.sm),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppText.body.copyWith(color: scheme.onSurfaceVariant),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: Space.xl),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

/// Something went wrong, stated without jargon, with a way out.
///
/// The app reports; it does not scold. There is no "⚠️ Action required"
/// register here and no emoji anywhere.
class ErrorState extends StatelessWidget {
  const ErrorState({
    required this.title,
    required this.message,
    this.onRetry,
    this.retryLabel = 'Try again',
    super.key,
  });

  final String title;
  final String message;
  final VoidCallback? onRetry;
  final String retryLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(Space.xxxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 40, color: scheme.error),
            const SizedBox(height: Space.xl),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppText.sectionHeader.copyWith(color: scheme.onSurface),
            ),
            const SizedBox(height: Space.sm),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppText.body.copyWith(color: scheme.onSurfaceVariant),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: Space.xl),
              OutlinedButton(onPressed: onRetry, child: Text(retryLabel)),
            ],
          ],
        ),
      ),
    );
  }
}

/// Placeholder rows shaped like the content that is coming.
///
/// A skeleton beats a spinner because it does not move the layout when
/// the data lands. The shimmer is a real animation, so it collapses to a
/// flat block when the platform has animations turned off.
class LoadingState extends StatelessWidget {
  const LoadingState({this.rows = 5, this.showHeader = false, super.key});

  final int rows;
  final bool showHeader;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(Space.lg),
      children: [
        if (showHeader) ...[
          const SkeletonBox(width: 180, height: 34),
          const SizedBox(height: Space.xxl),
        ],
        for (var i = 0; i < rows; i++)
          const Padding(
            padding: EdgeInsets.only(bottom: Space.lg),
            child: _SkeletonRow(),
          ),
      ],
    );
  }
}

class _SkeletonRow extends StatelessWidget {
  const _SkeletonRow();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        SkeletonBox(width: 40, height: 40, radius: 20),
        SizedBox(width: Space.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SkeletonBox(width: 140, height: 14),
              SizedBox(height: Space.sm),
              SkeletonBox(width: 90, height: 12),
            ],
          ),
        ),
        SizedBox(width: Space.md),
        SkeletonBox(width: 72, height: 16),
      ],
    );
  }
}

/// A single pulsing placeholder block.
class SkeletonBox extends StatefulWidget {
  const SkeletonBox({
    required this.width,
    required this.height,
    this.radius = Radii.input,
    super.key,
  });

  final double width;
  final double height;
  final double radius;

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Honour the system animation scale: a reduced-motion user gets a
    // static block rather than a pulse.
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
      _controller.value = 0.5;
    } else if (!_controller.isAnimating) {
      unawaited(_controller.repeat(reverse: true));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: Color.lerp(
              scheme.surfaceContainerHigh,
              scheme.surfaceContainerLow,
              _controller.value,
            ),
            borderRadius: BorderRadius.circular(widget.radius),
          ),
        );
      },
    );
  }
}
