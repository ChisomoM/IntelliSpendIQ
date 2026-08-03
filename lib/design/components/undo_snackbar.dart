import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intellispendiq/design/tokens/motion.dart';

/// Soft-delete undo: holds for [Motion.undoHold], then fades. Call
/// [onUndo] only if the user taps Undo before the snackbar dismisses.
void showUndoSnackBar(
  BuildContext context, {
  required String message,
  required FutureOr<void> Function() onUndo,
}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      content: Text(message),
      duration: Motion.of(context, Motion.undoHold),
      action: SnackBarAction(
        label: 'Undo',
        onPressed: () {
          unawaited(Future.sync(onUndo));
        },
      ),
    ),
  );
}
