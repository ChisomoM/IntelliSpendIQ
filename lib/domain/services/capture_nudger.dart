import 'dart:async';
import 'dart:developer';

import 'package:intellispendiq/core/deep_link.dart';
import 'package:intellispendiq/core/money.dart';
import 'package:intellispendiq/data/repositories/nudge_settings_repository.dart';
import 'package:intellispendiq/domain/models/enums.dart';
import 'package:intellispendiq/domain/models/transaction.dart';
import 'package:intellispendiq/domain/services/capture_service.dart';
import 'package:intl/intl.dart';

/// Reacts to a live capture by asking the user, while they still
/// remember it, what an uncategorized transaction was.
abstract interface class CaptureNudger {
  Future<void> onIngest(IngestResult result);

  /// Posts anything still being held back. The running app lets a short
  /// window collect a burst; the background path calls this so it can
  /// finish before its engine is torn down.
  Future<void> flush();

  Future<void> dispose();
}

/// Does nothing. Stands in wherever there is no notification plugin.
class NoopCaptureNudger implements CaptureNudger {
  @override
  Future<void> onIngest(IngestResult result) async {}

  @override
  Future<void> flush() async {}

  @override
  Future<void> dispose() async {}
}

/// What to put on screen. Kept free of any plugin type so the batching
/// rules can be tested without platform channels.
class NudgeMessage {
  const NudgeMessage({
    required this.id,
    required this.title,
    required this.body,
    required this.link,
    this.actions = const [],
    this.transactionId,
    this.options = const [],
  });

  /// Stable per message, so re-posting replaces rather than stacks.
  final int id;
  final String title;
  final String body;

  /// Deep link opened when the notification is tapped.
  final Uri link;

  /// One-tap answers shown on the notification itself.
  final List<NudgeAction> actions;

  /// The transaction a single nudge is about; null for a batched one.
  final String? transactionId;

  /// Every category the floating card's dropdown can offer. Empty when
  /// the card is off, which is how the card knows not to appear.
  final List<NudgeAction> options;
}

/// A button on a nudge that files the transaction under a category
/// without opening the app.
class NudgeAction {
  const NudgeAction({required this.categoryId, required this.label});

  /// Prefix of an action id; the rest is the category id.
  static const idPrefix = 'cat:';

  final String categoryId;
  final String label;

  String get id => '$idPrefix$categoryId';

  /// The category a tapped action id stands for, or null for any other
  /// action (reminders have their own).
  static String? categoryIdOf(String? actionId) {
    if (actionId == null || !actionId.startsWith(idPrefix)) return null;
    final categoryId = actionId.substring(idPrefix.length);
    return categoryId.isEmpty ? null : categoryId;
  }

  /// The transaction a nudge's payload (its deep link) points at.
  static String? transactionIdOf(String? payload) {
    final uri = payload == null ? null : Uri.tryParse(payload);
    if (uri == null) return null;
    return switch (DeepLink.parse(uri)) {
      TransactionLink(:final id) => id,
      _ => null,
    };
  }
}

/// Supplies the buttons for a single-transaction nudge.
typedef NudgeSuggestions = Future<List<NudgeAction>> Function();

/// Supplies every category the floating card's dropdown lists.
typedef NudgeCategoryOptions = Future<List<NudgeAction>> Function();

/// Shows a [NudgeMessage] to the user.
abstract interface class NudgeNotifier {
  Future<void> show(NudgeMessage message);
}

/// Decides which captures deserve a nudge.
abstract final class NudgePolicy {
  /// How long after the money moved a nudge is still worth sending.
  /// Anything older came from a backfill or a delayed SMS, and the
  /// moment to ask has passed.
  static const freshness = Duration(hours: 2);

  /// Only a newly saved spend that the categorizer could not place.
  /// Anything it did place needs no help, and money received rarely
  /// needs one.
  static bool isEligible(IngestResult result, DateTime now) {
    if (result.status != IngestStatus.saved) return false;
    final transaction = result.transaction;
    if (transaction == null) return false;
    if (transaction.categoryId != null) return false;
    if (transaction.direction != TxDirection.debit) return false;
    return now.difference(transaction.transactedAt) <= freshness;
  }
}

/// Collects eligible captures for a short window, then posts one
/// notification: a single capture names what was spent, a burst
/// becomes one "N need a category" so a flurry of messages never turns
/// into a flurry of alerts.
class BatchingCaptureNudger implements CaptureNudger {
  BatchingCaptureNudger({
    required NudgeSettingsRepository settings,
    required NudgeNotifier notifier,
    NudgeSuggestions? suggestions,
    NudgeCategoryOptions? categoryOptions,
    Duration window = const Duration(seconds: 3),
    DateTime Function()? clock,
  }) : _settings = settings,
       _notifier = notifier,
       _suggestions = suggestions,
       _categoryOptions = categoryOptions,
       _window = window,
       _clock = clock ?? DateTime.now;

  /// Notification id shared by every batched ("N need a category") post.
  static const batchNotificationId = 2000;

  final NudgeSettingsRepository _settings;
  final NudgeNotifier _notifier;
  final NudgeSuggestions? _suggestions;
  final NudgeCategoryOptions? _categoryOptions;
  final Duration _window;
  final DateTime Function() _clock;

  final _pending = <Transaction>[];
  Timer? _timer;

  @override
  Future<void> onIngest(IngestResult result) async {
    final now = _clock();
    if (!NudgePolicy.isEligible(result, now)) return;
    final settings = await _settings.load();
    if (!settings.enabled || settings.isQuiet(now.toLocal())) return;

    _pending.add(result.transaction!);
    _timer ??= Timer(_window, () => unawaited(flush()));
  }

  /// Posts whatever has been collected. Called by the window timer, and
  /// directly by the background path and by tests.
  @override
  Future<void> flush() async {
    _timer?.cancel();
    _timer = null;
    if (_pending.isEmpty) return;
    final batch = List<Transaction>.of(_pending);
    _pending.clear();
    try {
      final settings = await _settings.load();
      final message = await _messageFor(batch, overlay: settings.overlay);
      await _notifier.show(message);
    } on Object catch (error, stackTrace) {
      // Run from a timer with nobody awaiting it, so without this a
      // failed post (a blocked channel, a bad icon) vanishes silently.
      log(
        'Could not show the categorize nudge',
        error: error,
        stackTrace: stackTrace,
        name: 'capture_nudger',
      );
    }
  }

  Future<NudgeMessage> _messageFor(
    List<Transaction> batch, {
    required bool overlay,
  }) async {
    if (batch.length > 1) {
      return NudgeMessage(
        id: batchNotificationId,
        title: '${batch.length} new transactions need a category',
        body: 'Tap to sort them while you still remember',
        link: Uri.parse('${DeepLink.scheme}://review'),
      );
    }
    final transaction = batch.single;
    final actions = await _list(_suggestions);
    final options = overlay
        ? await _list(_categoryOptions)
        : const <NudgeAction>[];
    final merchant = transaction.merchant?.trim();
    final local = transaction.transactedAt.toLocal();
    final time = DateFormat('h:mm a').format(local);
    return NudgeMessage(
      id: transaction.id.hashCode & 0x7fffffff,
      title: 'What was this?',
      body: [
        Money.display(transaction.amountMinor),
        if (merchant != null && merchant.isNotEmpty) merchant,
        time,
      ].join(' · '),
      link: Uri.parse('${DeepLink.scheme}://transaction/${transaction.id}'),
      actions: actions,
      transactionId: transaction.id,
      options: options,
    );
  }

  /// A failure to suggest must never cost the user the nudge itself.
  Future<List<NudgeAction>> _list(
    Future<List<NudgeAction>> Function()? source,
  ) async {
    try {
      return await source?.call() ?? const [];
    } on Object {
      return const [];
    }
  }

  @override
  Future<void> dispose() async {
    _timer?.cancel();
    _timer = null;
    _pending.clear();
  }
}
