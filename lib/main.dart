import 'dart:async';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:intellispendiq/app/app.dart';
import 'package:intellispendiq/app/app_services.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (details) {
    log(details.exceptionAsString(), stackTrace: details.stack);
  };

  try {
    final services = await AppServices.bootstrap();
    runApp(IntelliSpendApp(services: services));
  } on Object catch (error, stackTrace) {
    // A failure here means the encrypted database could not be opened.
    // Show the reason rather than a blank screen — the alternative
    // (falling back to an unencrypted DB) would silently break the
    // security guarantee.
    log('Startup failed', error: error, stackTrace: stackTrace);
    runApp(StartupFailureApp(error: error.toString()));
  }
}
