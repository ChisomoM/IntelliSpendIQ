import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:c_template_app/auth/auth.dart';

class AppVersion extends StatelessWidget {
  const AppVersion({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final appVersion = context.select<AuthBloc, String>(
      (bloc) => bloc.state.appVersion,
    );
    return Semantics(
      label: 'App Version: $appVersion',
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'Version: ',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          Text(appVersion),
        ],
      ),
    );
  }
}
