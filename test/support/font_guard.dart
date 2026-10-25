import 'dart:async';

/// Runs [body] while ignoring failed Google Fonts downloads. The app's
/// text styles ask for their typeface over the network, which a test
/// cannot do; any other error still fails the test.
Future<void> ignoringFontFetchErrors(Future<void> Function() body) {
  final done = Completer<void>();
  runZonedGuarded(
    () async {
      try {
        await body();
        done.complete();
      } on Object catch (error, stack) {
        done.completeError(error, stack);
      }
    },
    (error, stack) {
      if ('$error'.contains('Failed to load font')) return;
      if (!done.isCompleted) done.completeError(error, stack);
    },
  );
  return done.future;
}
