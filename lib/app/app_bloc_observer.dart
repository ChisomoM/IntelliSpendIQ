import 'dart:developer';

import 'package:bloc/bloc.dart';

/// Observes every bloc/cubit transition and error in one place.
///
/// Capture bugs are the expensive kind in this app, so state changes are
/// logged rather than left invisible.
class AppBlocObserver extends BlocObserver {
  const AppBlocObserver();

  @override
  void onChange(BlocBase<dynamic> bloc, Change<dynamic> change) {
    super.onChange(bloc, change);
    log('${bloc.runtimeType} $change', name: 'bloc');
  }

  @override
  void onError(BlocBase<dynamic> bloc, Object error, StackTrace stackTrace) {
    log(
      '${bloc.runtimeType}',
      error: error,
      stackTrace: stackTrace,
      name: 'bloc',
    );
    super.onError(bloc, error, stackTrace);
  }
}
