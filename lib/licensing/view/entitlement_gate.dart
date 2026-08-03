import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intellispendiq/design/design.dart';
import 'package:intellispendiq/licensing/cubit/cubit.dart';
import 'package:intellispendiq/licensing/entitlement.dart';
import 'package:intellispendiq/licensing/view/hard_block_screen.dart';
import 'package:intellispendiq/licensing/view/payment_instructions.dart';
import 'package:intellispendiq/splash/splash.dart';

/// Evaluates the cached / refreshed license before the PIN gate.
class EntitlementGate extends StatefulWidget {
  const EntitlementGate({required this.child, super.key});

  final Widget child;

  @override
  State<EntitlementGate> createState() => _EntitlementGateState();
}

class _EntitlementGateState extends State<EntitlementGate>
    with WidgetsBindingObserver {
  bool _gracePromptShown = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    context.read<EntitlementCubit>().loadUnawaited();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      context.read<EntitlementCubit>().refreshUnawaited();
    }
  }

  Future<void> _maybePromptGrace(EntitlementStatus status) async {
    if (status != EntitlementStatus.grace || _gracePromptShown) return;
    _gracePromptShown = true;
    await Future<void>.delayed(Duration.zero);
    if (!mounted) return;
    await showPaywallModal(context, canDismiss: true);
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<EntitlementCubit, EntitlementState>(
      listenWhen: (previous, current) => previous.status != current.status,
      listener: (context, state) {
        unawaited(_maybePromptGrace(state.status));
      },
      builder: (context, state) {
        if (!state.isResolved || state.phase == EntitlementPhase.loading) {
          return const SplashView();
        }

        if (state.phase == EntitlementPhase.signedOut) {
          // IdentityGate will show sign-in; keep splash briefly.
          return const SplashView();
        }

        if (state.phase == EntitlementPhase.needsNetwork ||
            state.phase == EntitlementPhase.error) {
          return _LicenseErrorScreen(
            message:
                state.errorMessage ??
                'Could not verify your license. Connect to the internet once.',
            onRetry: () => context.read<EntitlementCubit>().loadUnawaited(),
            onSignOut: () async {
              await context.read<IdentityCubit>().signOut();
              if (context.mounted) {
                await context.read<EntitlementCubit>().signOut();
              }
            },
          );
        }

        if (state.phase == EntitlementPhase.blocked) {
          return const HardBlockScreen();
        }

        // allowed (trial / grace / active)
        return widget.child;
      },
    );
  }
}

class _LicenseErrorScreen extends StatelessWidget {
  const _LicenseErrorScreen({
    required this.message,
    required this.onRetry,
    required this.onSignOut,
  });

  final String message;
  final VoidCallback onRetry;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Space.gutter),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: Space.x3),
              FilledButton(onPressed: onRetry, child: const Text('Retry')),
              TextButton(onPressed: onSignOut, child: const Text('Sign out')),
            ],
          ),
        ),
      ),
    );
  }
}
