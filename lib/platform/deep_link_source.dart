import 'dart:async';

import 'package:app_links/app_links.dart';

/// Incoming links from the OS, behind an interface so cubit tests can
/// feed URIs without a plugin.
abstract interface class DeepLinkSource {
  /// The link that launched the app from cold, if any.
  Future<Uri?> initialLink();

  /// Links delivered while the app is already running.
  Stream<Uri> links();
}

class AppLinksSource implements DeepLinkSource {
  AppLinksSource({AppLinks? appLinks}) : _appLinks = appLinks ?? AppLinks();

  final AppLinks _appLinks;

  @override
  Future<Uri?> initialLink() => _appLinks.getInitialLink();

  @override
  Stream<Uri> links() => _appLinks.uriLinkStream;
}

/// Merges several [DeepLinkSource]s into one — e.g. real OS app links
/// plus `ReminderScheduler`'s notification taps — so `DeepLinkCubit`
/// keeps listening to exactly one source.
class CompositeDeepLinkSource implements DeepLinkSource {
  CompositeDeepLinkSource(this._sources);

  final List<DeepLinkSource> _sources;

  @override
  Future<Uri?> initialLink() async {
    for (final source in _sources) {
      final link = await source.initialLink();
      if (link != null) return link;
    }
    return null;
  }

  @override
  Stream<Uri> links() {
    late final StreamController<Uri> controller;
    final subscriptions = <StreamSubscription<Uri>>[];
    controller = StreamController<Uri>.broadcast(
      onListen: () {
        for (final source in _sources) {
          subscriptions.add(source.links().listen(controller.add));
        }
      },
      onCancel: () async {
        for (final subscription in subscriptions) {
          await subscription.cancel();
        }
        subscriptions.clear();
      },
    );
    return controller.stream;
  }
}
