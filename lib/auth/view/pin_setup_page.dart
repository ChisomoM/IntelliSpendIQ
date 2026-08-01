import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intellispendiq/auth/cubit/cubit.dart';
import 'package:intellispendiq/auth/widgets/widgets.dart';
import 'package:intellispendiq/data/repositories/app_lock_repository.dart';
import 'package:intellispendiq/design/design.dart';

/// Sets a PIN for the first time, or replaces an existing one.
class PinSetupPage extends StatelessWidget {
  const PinSetupPage({this.requireCurrentPin = false, super.key});

  /// True when replacing a PIN, so the user must prove they know the
  /// old one first.
  final bool requireCurrentPin;

  /// Pops with `true` once a PIN has been stored.
  static Route<bool> route({bool requireCurrentPin = false}) =>
      MaterialPageRoute<bool>(
        builder: (_) => PinSetupPage(requireCurrentPin: requireCurrentPin),
      );

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => PinSetupCubit(
        context.read<AppLockRepository>(),
        requireCurrentPin: requireCurrentPin,
      ),
      child: const PinSetupView(),
    );
  }
}

class PinSetupView extends StatelessWidget {
  const PinSetupView({super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<PinSetupCubit>();

    return BlocListener<PinSetupCubit, PinSetupState>(
      listenWhen: (previous, current) =>
          current.status == PinSetupStatus.success,
      listener: (context, state) {
        // The lock is now on; tell whoever pushed us so they can
        // refresh what the lock screen offers.
        Navigator.of(context).pop(true);
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('App lock')),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            child: BlocBuilder<PinSetupCubit, PinSetupState>(
              builder: (context, state) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppIcon(
                      AppIcons.lock,
                      size: 48,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: Space.x2),
                    Text(
                      state.title,
                      textAlign: TextAlign.center,
                      style: AppTypography.screenTitle(),
                    ),
                    const SizedBox(height: Space.x1),
                    Text(
                      '${AppLockRepository.minPinLength}'
                      '–${AppLockRepository.maxPinLength} digits. '
                      'There is no way to recover a forgotten PIN, '
                      'because nothing about it leaves this phone.',
                      textAlign: TextAlign.center,
                      style: AppTypography.metadata(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: Space.x4),
                    PinEntryField(
                      // Remounts between steps so the field genuinely
                      // starts empty rather than reusing the last value.
                      key: ValueKey(state.step),
                      value: state.entry,
                      enabled: !state.isBusy,
                      onChanged: cubit.pinChanged,
                      onSubmitted: cubit.submitUnawaited,
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
                      onPressed: state.isBusy ? null : cubit.submitUnawaited,
                      child: Text(
                        state.step == PinSetupStep.confirm
                            ? 'Save PIN'
                            : 'Continue',
                      ),
                    ),
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
