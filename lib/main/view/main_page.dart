import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:c_template_app/main/cubit/main_cubit.dart';
import 'package:c_template_app/main/widgets/main_body.dart';
import 'package:c_template_app/utils/deep_link_service.dart';

/// {@template main_page}
/// A description for MainPage
/// {@endtemplate}
class MainPage extends StatefulWidget {
  /// {@macro main_page}
  const MainPage({this.deepLinkService, super.key});

  final DeepLinkService? deepLinkService;

  /// The static route for MainPage
  static Route<dynamic> route() {
    return MaterialPageRoute<dynamic>(builder: (_) => const MainPage());
  }

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  @override
  void initState() {
    super.initState();
    widget.deepLinkService?.linkStream.listen((link) {
      if (link != null) {
        _handleDeepLink(link);
      }
    });
  }

  void _handleDeepLink(String link) {
    // Parse the link and navigate
    // Example: app://profile -> navigate to profile
    if (link.startsWith('app://profile')) {
      // Navigate to profile screen (for now, just print)
      print('Navigate to profile');
    } else if (link.startsWith('app://settings')) {
      print('Navigate to settings');
    }
    // Add more routes as needed
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => MainCubit(),
      child: const Scaffold(
        body: MainView(),
      ),
    );
  }
}

/// {@template main_view}
/// Displays the Body of MainView
/// {@endtemplate}
class MainView extends StatelessWidget {
  /// {@macro main_view}
  const MainView({super.key});

  @override
  Widget build(BuildContext context) {
    return const MainBody();
  }
}
