import 'package:flutter/material.dart';
import 'package:c_template_app/splash/cubit/cubit.dart';
import 'package:c_template_app/splash/widgets/splash_body.dart';

class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  static Route<dynamic> route() {
    return MaterialPageRoute<dynamic>(builder: (_) => const SplashPage());
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => SplashCubit(),
      child: BlocListener<SplashCubit, SplashState>(
        listener: (context, state) {},
        child: const Scaffold(
          body: SplashBody(),
        ),
      ),
    );
  }
}
