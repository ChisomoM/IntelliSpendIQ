import 'dart:developer';

import 'package:flutter/services.dart';
import 'package:intellispendiq/domain/services/capture_nudger.dart';

/// Floats a small card over whatever app is open, with the usual
/// categories as buttons and a dropdown of all of them, so a transaction
/// can be filed without leaving that app.
///
/// The card itself is drawn by native code (`NudgeOverlay.kt`): it has to
/// outlive the Dart engine that decided to show it, because the engine
/// the SMS receiver starts is torn down within seconds. This class only
/// hands native the words and the choices.
///
/// Needs the system's "Display over other apps" permission; without it
/// native declines and the notification is all the user gets.
class OverlayNudgeNotifier implements NudgeNotifier {
  OverlayNudgeNotifier({
    required MethodChannel channel,
    bool Function()? isSuppressed,
  }) : _channel = channel,
       _isSuppressed = isSuppressed;

  final MethodChannel _channel;

  /// True while a card would only be in the way, e.g. the app itself is
  /// on screen.
  final bool Function()? _isSuppressed;

  @override
  Future<void> show(NudgeMessage message) async {
    final transactionId = message.transactionId;
    // A batch, or the card is switched off: nothing to choose from.
    if (transactionId == null || message.options.isEmpty) return;
    if (_isSuppressed?.call() ?? false) return;

    Map<String, Object?> option(NudgeAction action) => {
      'id': action.categoryId,
      'label': action.label,
    };

    await _channel.invokeMethod<bool>('showOverlay', {
      'transactionId': transactionId,
      'notificationId': message.id,
      'title': message.title,
      'body': message.body,
      'suggestions': message.actions.map(option).toList(),
      'options': message.options.map(option).toList(),
    });
  }
}

/// Shows a nudge in several ways at once. One failing never stops the
/// others: the notification is the dependable one and must not be lost
/// to a problem with the floating card.
class CompositeNudgeNotifier implements NudgeNotifier {
  CompositeNudgeNotifier(this._notifiers);

  final List<NudgeNotifier> _notifiers;

  @override
  Future<void> show(NudgeMessage message) async {
    for (final notifier in _notifiers) {
      try {
        await notifier.show(message);
      } on Object catch (error, stackTrace) {
        log(
          'A nudge notifier failed',
          error: error,
          stackTrace: stackTrace,
          name: 'composite_nudge_notifier',
        );
      }
    }
  }
}
