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
