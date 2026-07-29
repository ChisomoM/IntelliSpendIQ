import 'package:equatable/equatable.dart';
import 'package:intellispendiq/core/app_section.dart';

/// A resolved in-app destination.
///
/// Parsing is pure and lives here rather than in the service, so the
/// whole link surface can be tested without a plugin or a device.
sealed class DeepLink extends Equatable {
  const DeepLink();

  /// Custom scheme, e.g. `intellispendiq://review`.
  static const scheme = 'intellispendiq';

  /// Verified app-link host, e.g. `https://intellispendiq.app/review`.
  static const webHost = 'intellispendiq.app';

  /// Returns null for anything unrecognised.
  ///
  /// Null is the safe answer: an unknown link should leave the user
  /// wherever they already were, not throw them somewhere arbitrary.
  static DeepLink? parse(Uri uri) {
    final segments = _segmentsOf(uri);
    if (segments.isEmpty) return null;

    return switch (segments) {
      ['add'] => const AddTransactionLink(),
      ['voice'] => const VoiceEntryLink(),
      ['transaction', final id] when id.isNotEmpty => TransactionLink(id),
      [final slug] when AppSection.fromSlug(slug) != null => SectionLink(
        AppSection.fromSlug(slug)!,
      ),
      _ => null,
    };
  }

  /// Flattens both link shapes to one segment list.
  ///
  /// Under the custom scheme the first word lands in [Uri.host]
  /// (`intellispendiq://review` has an empty path), whereas an https
  /// app link carries everything in the path.
  static List<String> _segmentsOf(Uri uri) {
    final path = uri.pathSegments.where((s) => s.isNotEmpty).toList();

    if (uri.scheme == scheme) {
      return [if (uri.host.isNotEmpty) uri.host, ...path];
    }
    if ((uri.scheme == 'https' || uri.scheme == 'http') &&
        uri.host == webHost) {
      return path;
    }
    return const [];
  }
}

/// Switch to a top-level tab.
class SectionLink extends DeepLink {
  const SectionLink(this.section);

  final AppSection section;

  @override
  List<Object?> get props => [section];
}

/// Open the manual entry form.
class AddTransactionLink extends DeepLink {
  const AddTransactionLink();

  @override
  List<Object?> get props => [];
}

/// Open the voice capture sheet.
class VoiceEntryLink extends DeepLink {
  const VoiceEntryLink();

  @override
  List<Object?> get props => [];
}

/// Open one transaction for editing.
class TransactionLink extends DeepLink {
  const TransactionLink(this.id);

  final String id;

  @override
  List<Object?> get props => [id];
}
