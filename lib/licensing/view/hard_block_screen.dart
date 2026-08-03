import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intellispendiq/design/design.dart';
import 'package:intellispendiq/licensing/cubit/cubit.dart';
import 'package:intellispendiq/licensing/entitlement.dart';
import 'package:intellispendiq/licensing/view/payment_instructions.dart';

/// Hard lock when trial+grace are over or the account is disabled.
/// Never wipes the local database.
class HardBlockScreen extends StatelessWidget {
  const HardBlockScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final status = context.select<EntitlementCubit, EntitlementStatus>(
      (c) => c.state.status,
    );
    final message = switch (status) {
      EntitlementStatus.disabled =>
        'Your account has been disabled. Contact support via WhatsApp '
        'if you believe this is a mistake.',
      EntitlementStatus.unknown =>
        'We need a network connection once to verify your license.',
      _ =>
        'Your trial has ended. Activate a subscription to keep using '
        'IntelliSpendIQ. Your local data is safe on this device.',
    };

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Space.gutter),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Icon(
                Icons.lock_outline,
                size: 56,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: Space.x2),
              Text(
                'Subscription required',
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: Space.x1),
              Text(
                message,
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: Space.x4),
              const PaymentInstructions(),
              const Spacer(),
              TextButton(
                onPressed: () =>
                    context.read<EntitlementCubit>().refreshUnawaited(),
                child: const Text('I paid — refresh license'),
              ),
              TextButton(
                onPressed: () async {
                  await context.read<IdentityCubit>().signOut();
                  if (context.mounted) {
                    await context.read<EntitlementCubit>().signOut();
                  }
                },
                child: const Text('Sign out'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
