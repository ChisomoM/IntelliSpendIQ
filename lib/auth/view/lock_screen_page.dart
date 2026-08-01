import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intellispendiq/auth/cubit/cubit.dart';
import 'package:intellispendiq/auth/widgets/widgets.dart';
import 'package:intellispendiq/design/design.dart';

/// Shown instead of the app when a PIN is set and unsatisfied.
///
/// There is no "forgot PIN" escape hatch on purpose: the data is on the
/// device only, so there is no server that could verify an identity and
/// reset it. Clearing app data is the honest recovery path, and it
/// destroys the records — which is the correct outcome for a stranger
/// holding the phone.
class LockScreenPage extends StatelessWidget {
  const LockScreenPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<AuthCubit>();

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: BlocBuilder<AuthCubit, AuthState>(
              builder: (context, state) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppIcon(
                      AppIcons.lock,
                      size: 56,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: Space.x3),
                    Text('Enter your PIN', style: AppTypography.screenTitle()),
                    const SizedBox(height: Space.x4),
                    PinEntryField(
                      value: state.pin,
                      enabled: !state.submitting,
                      onChanged: cubit.pinChanged,
                      onSubmitted: cubit.submitPinUnawaited,
                    ),
                    if (state.errorMessage != null) ...[
                      const SizedBox(height: Space.x1),
                      Text(
                        state.errorMessage!,
                        textAlign: TextAlign.center,
                        style: AppTypography.metadata(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                    const SizedBox(height: Space.x2),
                    FilledButton(
                      onPressed: state.submitting
                          ? null
                          : cubit.submitPinUnawaited,
                      child: state.submitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Unlock'),
                    ),
                    if (state.canUseBiometrics) ...[
                      const SizedBox(height: Space.x1),
                      TextButton.icon(
                        onPressed: state.submitting
                            ? null
                            : cubit.unlockWithBiometricsUnawaited,
                        icon: AppIcon(AppIcons.fingerprint, size: 18),
                        label: const Text('Use biometrics'),
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
