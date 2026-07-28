import 'dart:async';
import 'dart:developer';

import 'package:analytics_repository/analytics_repository.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:c_template_app/firebase_options.dart';
import 'package:c_template_app/utils/app_bloc_observer.dart';
import 'package:c_template_app/utils/config.dart';
import 'package:local_data/local_data.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
// import 'package:c_template_app/firebase_options.dart';
// import 'package:c_template_app/utils/app_bloc_observer.dart';
// import 'package:c_template_app/utils/config.dart';

typedef AppBuilder =
    Future<Widget> Function(
      // FirebaseMessaging firebaseMessaging,
      SharedPrefs prefs,
      AnalyticsRepo analyticsRepository,
      FirebaseAuth auth,
      GoogleSignIn googleSignIn,
      SignInWithApple signInWithApple,
    );

Future<void> bootstrap(
  AppBuilder builder, {
  AppEnv env = AppEnv.development,
}) async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  final analyticsRepository = AnalyticsRepo(FirebaseAnalytics.instance);
  final blocObserver = AppBlocObserver(
    analyticsRepository: analyticsRepository,
  );
  Bloc.observer = blocObserver;

  FlutterError.onError = (details) {
    log(details.exceptionAsString(), stackTrace: details.stack);
  };
  // Add cross-flavor configuration here

  final prefs = await SharedPrefs.init();

  runApp(
    await builder(
      prefs,
      analyticsRepository,
      FirebaseAuth.instance,
      GoogleSignIn(),
      SignInWithApple(),
    ),
  );
}
