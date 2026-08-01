import 'package:flutter/material.dart';
import 'package:intellispendiq/design/components/app_icon.dart';
import 'package:intellispendiq/design/tokens/icons.dart';
import 'package:intellispendiq/design/tokens/spacing.dart';
import 'package:intellispendiq/design/tokens/typography.dart';

/// A failure a person can act on: what happened, in plain words, and a
/// retry when the operation is genuinely repeatable. Replaces the
/// generic snackbars that carry `state.errorMessage` today with no
/// distinction between "no API key" and "network failed".
class ErrorState extends StatelessWidget {
  const ErrorState({
    required this.message,
    this.onRetry,
    super.key,
  });

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Space.x4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppIcon(AppIcons.unknown, size: 40, color: colors.error),
            const SizedBox(height: Space.x2),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTypography.body(color: colors.onSurface),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: Space.x2),
              OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
            ],
          ],
        ),
      ),
    );
  }
}
