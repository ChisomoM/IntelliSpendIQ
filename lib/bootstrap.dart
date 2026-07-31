import 'dart:async';
import 'dart:developer';

import 'package:bloc/bloc.dart';
import 'package:flutter/widgets.dart';
import 'package:intellispendiq/app/app_bloc_observer.dart';
import 'package:intellispendiq/app/app_services.dart';
import 'package:intellispendiq/splash/splash.dart';

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
  // Binding init and runApp must share one zone — otherwise Flutter
  // warns about zone mismatch and callbacks can pick the wrong config.
  await runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      FlutterError.onError = (details) {
        log(
          details.exceptionAsString(),
          stackTrace: details.stack,
          name: 'flutter',
        );
      };

      Bloc.observer = const AppBlocObserver();

      // Paint something first. Deriving the SQLCipher key and opening
      // the database is slow enough to be visible, and without this the
      // user stares at a blank window while it happens.
      runApp(const SplashApp());

      final services = await AppServices.bootstrap(flavor: flavor);
      runApp(await builder(services));
    },
    (error, stackTrace) {
      log('Uncaught zone error', error: error, stackTrace: stackTrace);
    },
  );
}
