import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intellispendiq/accounts/accounts.dart';
import 'package:intellispendiq/app/cubit/cubit.dart';
import 'package:intellispendiq/auth/auth.dart';
import 'package:intellispendiq/data/repositories/app_lock_repository.dart';
import 'package:intellispendiq/settings/cubit/cubit.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          SettingsCubit(context.read<AppLockRepository>())..loadUnawaited(),
      child: const SettingsView(),
    );
  }
}

class SettingsView extends StatelessWidget {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const _SectionHeader('Appearance'),
          const _ThemeSelector(),
          const Divider(height: 32),
          const _SectionHeader('Money'),
          ListTile(
            leading: const Icon(Icons.account_balance_wallet_outlined),
            title: const Text('Accounts'),
            subtitle: const Text(
              'Manage cash, bank, and mobile money accounts',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push<void>(AccountsPage.route()),
          ),
          const Divider(height: 32),
          const _SectionHeader('Security'),
          const _AppLockSection(),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ThemeSelector extends StatelessWidget {
  const _ThemeSelector();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ThemeCubit, ThemeMode>(
      builder: (context, mode) {
        return Column(
          children: [
            for (final option in ThemeMode.values)
              ListTile(
                title: Text(_label(option)),
                trailing: option == mode
                    ? Icon(
                        Icons.check,
                        color: Theme.of(context).colorScheme.primary,
                      )
                    : null,
                onTap: () =>
                    context.read<ThemeCubit>().setThemeModeUnawaited(option),
              ),
          ],
        );
      },
    );
  }

  String _label(ThemeMode mode) => switch (mode) {
    ThemeMode.system => 'Follow system',
    ThemeMode.light => 'Light',
    ThemeMode.dark => 'Dark',
  };
}

class _AppLockSection extends StatelessWidget {
  const _AppLockSection();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsCubit, SettingsState>(
      builder: (context, state) {
        if (state.status == SettingsStatus.initial) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        return Column(
          children: [
            if (!state.pinSet)
              ListTile(
                leading: const Icon(Icons.lock_open),
                title: const Text('Set up app lock'),
                subtitle: const Text(
                  'Require a PIN to open IntelliSpendIQ. Capture keeps '
                  'running while locked.',
                ),
                onTap: () => _setUpPin(context),
              )
            else ...[
              ListTile(
                leading: const Icon(Icons.pin_outlined),
                title: const Text('Change PIN'),
                onTap: () => _setUpPin(context, requireCurrentPin: true),
              ),
              if (state.biometricsAvailable)
                SwitchListTile(
                  secondary: const Icon(Icons.fingerprint),
                  title: const Text('Unlock with biometrics'),
                  value: state.biometricsEnabled,
                  onChanged: (enabled) => _setBiometrics(context, enabled),
                ),
              ListTile(
                leading: const Icon(Icons.lock_outline),
                title: const Text('Lock now'),
                onTap: context.read<AuthCubit>().lockUnawaited,
              ),
              ListTile(
                leading: Icon(
                  Icons.no_encryption_outlined,
                  color: Theme.of(context).colorScheme.error,
                ),
                title: Text(
                  'Turn off app lock',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
                onTap: () => _confirmDisable(context),
              ),
            ],
          ],
        );
      },
    );
  }

  Future<void> _setUpPin(
    BuildContext context, {
    bool requireCurrentPin = false,
  }) async {
    final settings = context.read<SettingsCubit>();
    final auth = context.read<AuthCubit>();

    final saved = await Navigator.of(context).push<bool>(
      PinSetupPage.route(requireCurrentPin: requireCurrentPin),
    );
    if (saved ?? false) {
      await settings.load();
      // The lock screen's biometric button depends on this.
      await auth.refreshBiometrics();
    }
  }

  Future<void> _setBiometrics(BuildContext context, bool enabled) async {
    await context.read<SettingsCubit>().setBiometricsEnabled(
      enabled: enabled,
    );
    if (context.mounted) await context.read<AuthCubit>().refreshBiometrics();
  }

  Future<void> _confirmDisable(BuildContext context) async {
    final settings = context.read<SettingsCubit>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Turn off app lock?'),
        content: const Text(
          'Anyone who picks up this phone unlocked will be able to see '
          'your spending. Your records themselves stay encrypted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Turn off'),
          ),
        ],
      ),
    );

    if (confirmed ?? false) await settings.disableLock();
  }
}
