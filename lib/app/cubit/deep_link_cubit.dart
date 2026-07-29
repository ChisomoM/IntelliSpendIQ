import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:intellispendiq/core/deep_link.dart';
import 'package:intellispendiq/platform/deep_link_source.dart';

part 'deep_link_state.dart';

/// Holds the link waiting to be acted on.
///
/// The cubit only ever *parks* a destination — it does no navigating.
/// `HomeView` picks it up and calls [consumed]. Since `HomeView` is
/// only mounted once the app is unlocked, a link that arrives at the
/// lock screen simply waits there, and deep links cannot be used to
/// walk past the gate. That gating is a property of where the listener
/// lives, so there is no separate check to forget.
class DeepLinkCubit extends Cubit<DeepLinkState> {
  DeepLinkCubit(this._source) : super(const DeepLinkState());

  final DeepLinkSource _source;
  StreamSubscription<Uri>? _subscription;

  Future<void> start() async {
    _subscription ??= _source.links().listen(_handle);

    final initial = await _source.initialLink();
    if (initial != null) _handle(initial);
  }

  void _handle(Uri uri) {
    final link = DeepLink.parse(uri);
    // Unrecognised links are dropped rather than parked, so a stale one
    // never fires later against a screen it was not meant for.
    if (link == null) return;
    emit(DeepLinkState(pending: link));
  }

  /// Called once the destination has been navigated to.
  void consumed() => emit(const DeepLinkState());

  void startUnawaited() => unawaited(start());

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}
