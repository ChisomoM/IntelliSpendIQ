import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intellispendiq/auth/cubit/cubit.dart';
import 'package:intellispendiq/auth/view/lock_screen_page.dart';
import 'package:intellispendiq/splash/splash.dart';

/// Stands between the app and its content.
///
/// Deliberately not a route: the gate wraps `home`, so no navigation
/// can get behind it and nothing needs to remember to check.
class AuthGate extends StatefulWidget {
  const AuthGate({required this.child, super.key});

  final Widget child;

  /// How long the app may sit in the background before it re-locks.
  ///
  /// Not zero, for a concrete reason: on Android the biometric prompt
  /// and the system permission dialogs both pause the activity. Locking
  /// the instant we are paused would re-lock the app underneath its own
  /// unlock prompt.
  static const lockGracePeriod = Duration(seconds: 30);

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> with WidgetsBindingObserver {
  DateTime? _backgroundedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    context.read<AuthCubit>().loadUnawaited();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        _backgroundedAt ??= DateTime.now();
      case AppLifecycleState.resumed:
        final since = _backgroundedAt;
        _backgroundedAt = null;
        if (since != null &&
            DateTime.now().difference(since) >= AuthGate.lockGracePeriod) {
          context.read<AuthCubit>().lockUnawaited();
        }
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthCubit, AuthState>(
      buildWhen: (previous, current) => previous.status != current.status,
      builder: (context, state) {
        if (!state.isResolved) return const SplashView();
        if (state.isUnlocked) return widget.child;
        return const LockScreenPage();
      },
    );
  }
}
