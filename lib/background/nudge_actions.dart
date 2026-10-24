import 'dart:developer';
import 'dart:ui';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intellispendiq/domain/services/capture_core.dart';
import 'package:intellispendiq/domain/services/capture_nudger.dart';

/// Answers a tap on one of a nudge's category buttons: files the
/// transaction without opening the app.
///
/// Returns true when [response] was one of ours and the transaction was
/// categorized. [openCore] is injectable so tests can supply an
/// in-memory database; a core supplied that way stays open, as closing
/// it is its owner's job.
Future<bool> handleNudgeAction(
  NotificationResponse response, {
  Future<CaptureCore> Function()? openCore,
}) async {
  final categoryId = NudgeAction.categoryIdOf(response.actionId);
  final transactionId = NudgeAction.transactionIdOf(response.payload);
  if (categoryId == null || transactionId == null) return false;

  final core = await (openCore ?? () => CaptureCore.open())();
  try {
    await core.categorize(transactionId, categoryId);
    return true;
  } finally {
    if (openCore == null) await core.dispose();
  }
}

/// Entrypoint the notification plugin runs, in its own isolate, when a
/// button with no user interface is tapped. Must be top level.
@pragma('vm:entry-point')
Future<void> nudgeActionBackground(NotificationResponse response) async {
  DartPluginRegistrant.ensureInitialized();
  try {
    await handleNudgeAction(response);
  } on Object catch (error, stackTrace) {
    log(
      'Nudge action failed',
      error: error,
      stackTrace: stackTrace,
      name: 'nudge_actions',
    );
  }
}
