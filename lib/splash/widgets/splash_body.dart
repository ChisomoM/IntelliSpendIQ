import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:c_template_app/splash/cubit/splash_cubit.dart';
import 'package:c_template_app/utils/app_icons.dart';
import 'package:c_template_app/utils/reusable_animations.dart';
import 'package:c_template_app/utils/screen_size.dart';
// import 'package:c_template_app/splash/cubit/splash_cubit.dart';
// import 'package:c_template_app/utils/app_icons.dart';
// import 'package:c_template_app/utils/reusable_animations.dart';
// import 'package:c_template_app/utils/screen_size.dart';

class SplashBody extends StatelessWidget {
  const SplashBody({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SplashCubit, SplashState>(
      builder: (context, state) {
        return Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomLeft,
              end: Alignment.topRight,
              colors: [
                Color(0xFF313180),
                Color(0xFF00A7D1),
              ],
              stops: [0.4, 0.9],
            ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FadeSlideAnimation(
                  direction: SlideDirection.fromTop,
                  child: SvgPicture.asset(
                    AppIcons.appLogo,
                    colorFilter: const ColorFilter.mode(
                      Colors.white,
                      BlendMode.srcATop,
                    ),
                    width: wp(600),
                    height: hp(84),
                  ),
                ),
                const SizedBox(height: 24),
                const FadeSlideAnimation(
                  child: Text(
                    'ZICTA TARIFF \nCOMPARATOR',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 48),
                if (state.isLoading) ...[
                  const CircularProgressIndicator(color: Colors.white),
                  const SizedBox(height: 16),
                  const Text(
                    'Loading...',
                    style: TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
