import 'dart:developer';

import 'package:c_template_app/app/app.dart';
import 'package:c_template_app/auth/auth.dart';
import 'package:c_template_app/bootstrap.dart';
import 'package:c_template_app/firebase_config.dart';
import 'package:c_template_app/utils/config.dart';
import 'package:c_template_app/utils/deep_link_service.dart';
import 'package:c_template_app/utils/utils.dart';
import 'package:local_data/local_data.dart';
import 'package:net_source/net_source.dart';
import 'package:notifications_repo/notifications_repo.dart';
import 'package:permission_client/permission_client.dart';
import 'package:services_repo/services_repo.dart';

void main() {
  final config = Config.dev();
  baseUrl = 'http://${config.host}';
  bootstrap((
    prefs,
    analyticsRepository,
    auth,
    googleSignIn,
    signInWithApple,
  ) async {
    // Initialize Firebase
    await FirebaseConfig.initialize(
      environment: 'development',
      enableFirestore: true, // Enable/disable as needed
      enableMessaging: true,
    );

    // Initialize Deep Link Service
    final deepLinkService = DeepLinkService();
    await deepLinkService.init();

    final db = await LocalData.init(
      dbName: config.dbName,
      initialScript: config.initScript,
      migrations: config.migrations,
    );
    final token = await prefs.getString('token');
    log(' user Token $token');
    final net = NetSource(
      baseUrl: config.baseUrl,
      host: config.host,
      token: token,
    );
    // final socket =
    //     await SocketSource.init(config.socketUrl, alwaysConnected: true);

    final authRepo = AuthRepo(
      signInWithApple: signInWithApple,
      googleSignIn: googleSignIn,
      auth: auth,
      isDev: true,
      prefs: prefs,
      db: db,
      net: net,
    );
    final servicesRepo = ServicesRepo(
      prefs: prefs,
      db: db,
      net: net,
      firestore: FirebaseConfig.firestore,
    );
    const permissionClient = PermissionClient();
    final notificationsRepo = NotificationsRepo(
      prefs: prefs,
      net: net,
      permissionClient: permissionClient,
    );
    return App(
      authRepo: authRepo,
      servicesRepo: servicesRepo,
      analyticsRepo: analyticsRepository,
      notificationsRepo: notificationsRepo,
      loggedIn: token != null,
      deepLinkService: deepLinkService,
    );
  });
}
