import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intellispendiq/design/tokens/spacing.dart';

/// A blocking "please wait" dialog for an async step with no
/// incremental progress to show — an AI API call, for instance. Pairs
/// [show] right before the operation with [hide] once it settles
/// (success or failure), so the screen never just sits there looking
/// like nothing happened while something actually is.
abstract final class AppLoadingDialog {
  static void show(BuildContext context, String message) {
    unawaited(
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => PopScope(
          canPop: false,
          child: AlertDialog(
            content: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
                const SizedBox(width: Space.x2),
                Expanded(child: Text(message)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Dismisses the dialog [show] opened. Targets the root navigator —
  /// same as `showDialog`'s default — so it closes reliably regardless
  /// of what navigator nesting sits between the caller and the root.
  static void hide(BuildContext context) {
    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
  }
}
