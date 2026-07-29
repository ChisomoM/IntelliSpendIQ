import 'dart:async';
import 'dart:developer';

import 'package:bloc/bloc.dart';
import 'package:flutter/widgets.dart';
import 'package:intellispendiq/app/app_bloc_observer.dart';
import 'package:intellispendiq/app/app_services.dart';

/// Build flavours (D02: all three sideload, none go to Play Store).
enum AppFlavor {
  development,
  staging,
  production;

  String get displayName => switch (this) {
    AppFlavor.development => '[DEV] IntelliSpendIQ',
    AppFlavor.staging => '[STG] IntelliSpendIQ',
    AppFlavor.production => 'IntelliSpendIQ',
  };
}

typedef AppBuilder = Future<Widget> Function(AppServices services);

/// Cross-flavour startup: error hooks, the bloc observer, and the
/// encrypted database, before the first frame.
Future<void> bootstrap(
  AppBuilder builder, {
  required AppFlavor flavor,
}) async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (details) {
    log(
      details.exceptionAsString(),
      stackTrace: details.stack,
      name: 'flutter',
    );
  };

  Bloc.observer = const AppBlocObserver();

  await runZonedGuarded(
    () async {
      final services = await AppServices.bootstrap(flavor: flavor);
      runApp(await builder(services));
    },
    (error, stackTrace) {
      log('Uncaught zone error', error: error, stackTrace: stackTrace);
    },
  );
}
