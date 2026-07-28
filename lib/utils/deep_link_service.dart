import 'dart:async';

import 'package:uni_links/uni_links.dart';

/// {@template deep_link_service}
/// Service for handling deep links and app links.
/// Listens for incoming links and emits navigation events.
/// {@endtemplate}
class DeepLinkService {
  /// {@macro deep_link_service}
  DeepLinkService();

  final _linkController = StreamController<String?>.broadcast();

  /// Stream of incoming deep links.
  Stream<String?> get linkStream => _linkController.stream;

  /// Initialize the service.
  Future<void> init() async {
    // Handle initial link if app was launched from a link
    try {
      final initialLink = await getInitialLink();
      if (initialLink != null) {
        _linkController.add(initialLink);
      }
    } catch (e) {
      // Handle error
    }

    // Listen for links while app is running
    linkStream.listen(
      (link) {
        if (link != null) {
          _linkController.add(link);
        }
      },
      onError: (err) {
        // Handle error
      },
    );
  }

  /// Dispose the service.
  void dispose() {
    _linkController.close();
  }
}
