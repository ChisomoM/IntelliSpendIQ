import 'package:flutter/material.dart';
import 'package:c_template_app/main/view/main_page.dart';
import 'package:c_template_app/utils/deep_link_service.dart';

class App extends StatelessWidget {
  const App({
    required this.authRepo,
    required this.servicesRepo,
    required this.notificationsRepo,
    required this.analyticsRepo,
    required this.loggedIn,
    this.deepLinkService,
    super.key,
  });

  final dynamic authRepo;
  final dynamic servicesRepo;
  final dynamic notificationsRepo;
  final dynamic analyticsRepo;
  final bool loggedIn;
  final DeepLinkService? deepLinkService;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: MainPage(deepLinkService: deepLinkService),
    );
  }
}
