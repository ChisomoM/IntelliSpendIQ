import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:c_template_app/utils/app_icons.dart';

class ComingSoon extends StatelessWidget {
  const ComingSoon({
    required this.theme,
    super.key,
  });

  final ColorScheme theme;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // App Logo
          SvgPicture.asset(
            AppIcons.appLogo,
            height: 80, // Increased from 40 to 80
            colorFilter: ColorFilter.mode(
              theme.primary,
              BlendMode.srcIn,
            ),
          ),
          const SizedBox(height: 48),
          // Coming Soon Illustration
          SvgPicture.asset(
            AppIcons.oops,
            height: 200,
            // Removed colorFilter to keep original colors
          ),
          const SizedBox(height: 32),
          // Sorry Text
          Text(
            'Sorry!',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: theme.primary,
            ),
          ),
          const SizedBox(height: 16),
          // Coming Soon Text
          Text(
            'This Service is\nComing Soon',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: theme.primary,
            ),
          ),
        ],
      ),
    );
  }
}
