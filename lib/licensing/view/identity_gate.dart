import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intellispendiq/licensing/cubit/cubit.dart';
import 'package:intellispendiq/licensing/view/sign_in_page.dart';

/// Ensures a Firebase identity exists before entitlement / PIN gates.
class IdentityGate extends StatefulWidget {
  const IdentityGate({required this.child, super.key});

  final Widget child;

  @override
  State<IdentityGate> createState() => _IdentityGateState();
}

class _IdentityGateState extends State<IdentityGate> {
  @override
  void initState() {
    super.initState();
    context.read<IdentityCubit>().loadUnawaited();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<IdentityCubit, IdentityState>(
      buildWhen: (previous, current) =>
          previous.isSignedIn != current.isSignedIn ||
          previous.busy != current.busy,
      builder: (context, state) {
        if (state.isSignedIn) return widget.child;
        // While a register/sign-in is in flight after success path, keep form.
        return const SignInPage();
      },
    );
  }
}
