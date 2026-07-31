import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intellispendiq/accounts/accounts.dart';
import 'package:intellispendiq/app/cubit/cubit.dart';
import 'package:intellispendiq/auth/auth.dart';
import 'package:intellispendiq/categories/categories.dart';
import 'package:intellispendiq/data/repositories/app_lock_repository.dart';
import 'package:intellispendiq/data/repositories/budget_period_repository.dart';
import 'package:intellispendiq/data/secure/secure_store.dart';
import 'package:intellispendiq/domain/services/backup_service.dart';
import 'package:intellispendiq/senders/senders.dart';
import 'package:intellispendiq/settings/budget_cadence_labels.dart';
import 'package:intellispendiq/settings/cubit/cubit.dart';
import 'package:intellispendiq/settings/view/budget_cycle_page.dart';
import 'package:share_plus/share_plus.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  static Route<void> route() {
    return MaterialPageRoute<void>(builder: (_) => const SettingsPage());
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => SettingsCubit(
        context.read<AppLockRepository>(),
        context.read<SecureStore>(),
      )..loadUnawaited(),
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
            leading: const Icon(Icons.date_range_outlined),
            title: const Text('Budget cycle'),
            subtitle: const _BudgetCycleSubtitle(),
            trailing: const Icon(Icons.chevron_right),
            onTap: () =>
                Navigator.of(context).push<void>(BudgetCyclePage.route()),
          ),
          ListTile(
            leading: const Icon(Icons.account_balance_wallet_outlined),
            title: const Text('Accounts'),
            subtitle: const Text(
              'Manage cash, bank, and mobile money accounts',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push<void>(AccountsPage.route()),
          ),
          ListTile(
            leading: const Icon(Icons.label_outline),
            title: const Text('Categories'),
            subtitle: const Text('Add or remove spending categories'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () =>
                Navigator.of(context).push<void>(CategoriesPage.route()),
          ),
          ListTile(
            leading: const Icon(Icons.sms_outlined),
            title: const Text('Message senders'),
            subtitle: const Text(
              "Recognize another bank or wallet's SMS alerts",
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () =>
                Navigator.of(context).push<void>(CustomSendersPage.route()),
          ),
          const Divider(height: 32),
          const _SectionHeader('Data'),
          const _DataSection(),
          const Divider(height: 32),
          const _SectionHeader('Security'),
          const _AppLockSection(),
          const Divider(height: 32),
          const _SectionHeader('AI'),
          const _AnthropicApiKeySection(),
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

class _BudgetCycleSubtitle extends StatelessWidget {
  const _BudgetCycleSubtitle();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: context.read<BudgetPeriodRepository>().ensureSchedule(),
      builder: (context, snapshot) {
        final schedule = snapshot.data;
        if (schedule == null) {
          return const Text('When each budget period starts and ends');
        }
        return Text(BudgetCadenceLabels.title(schedule.cadence));
      },
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

/// Export and backup actions. Restore merges into what's already on
/// this device — see [BackupService] for why that's safe to repeat.
class _DataSection extends StatefulWidget {
  const _DataSection();

  @override
  State<_DataSection> createState() => _DataSectionState();
}

class _DataSectionState extends State<_DataSection> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(
          leading: const Icon(Icons.table_chart_outlined),
          title: const Text('Export transactions (CSV)'),
          subtitle: const Text('For your own records or a spreadsheet'),
          enabled: !_busy,
          onTap: () => _exportCsv(context),
        ),
        ListTile(
          leading: const Icon(Icons.backup_outlined),
          title: const Text('Back up all data (JSON)'),
          subtitle: const Text(
            'Accounts, categories, budgets, and transactions',
          ),
          enabled: !_busy,
          onTap: () => _exportBackup(context),
        ),
        ListTile(
          leading: const Icon(Icons.restore_outlined),
          title: const Text('Restore from backup'),
          subtitle: const Text(
            "Adds a backup file's data to what is already here",
          ),
          enabled: !_busy,
          onTap: () => _restoreBackup(context),
        ),
        if (_busy)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }

  Future<void> _exportCsv(BuildContext context) async {
    final backup = context.read<BackupService>();
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      final file = await backup.exportTransactionsCsv();
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: 'IntelliSpendIQ transactions export',
        ),
      );
    } on Exception catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('Could not export: $error')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _exportBackup(BuildContext context) async {
    final backup = context.read<BackupService>();
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      final file = await backup.exportBackupJson();
      await SharePlus.instance.share(
        ShareParams(files: [XFile(file.path)], text: 'IntelliSpendIQ backup'),
      );
    } on Exception catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('Could not export: $error')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restoreBackup(BuildContext context) async {
    final backup = context.read<BackupService>();
    final messenger = ScaffoldMessenger.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Restore from backup?'),
        content: const Text(
          'This adds every account, category, budget, and transaction '
          'from the backup file that is not already here. Nothing '
          'already on this device is removed or changed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Choose file'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    final path = result?.files.single.path;
    if (path == null || !mounted) return;

    setState(() => _busy = true);
    try {
      final summary = await backup.importBackupJson(File(path));
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Restored ${summary.totalImported} record(s) '
            '(${summary.skipped} already present).',
          ),
        ),
      );
    } on Exception catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('Could not restore that file: $error')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _AnthropicApiKeySection extends StatelessWidget {
  const _AnthropicApiKeySection();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsCubit, SettingsState>(
      builder: (context, state) {
        if (state.status == SettingsStatus.initial) {
          return const SizedBox.shrink();
        }

        return Column(
          children: [
            ListTile(
              leading: Icon(
                state.anthropicApiKeyConfigured
                    ? Icons.check_circle_outline
                    : Icons.key_outlined,
              ),
              title: const Text('Anthropic API key'),
              subtitle: Text(
                state.anthropicApiKeyConfigured
                    ? 'Configured — used for voice and assistant'
                    : 'Paste in secrets.json, or here',
              ),
              onTap: () => _editKey(
                context,
                configured: state.anthropicApiKeyConfigured,
              ),
            ),
            if (state.anthropicApiKeyConfigured)
              ListTile(
                leading: Icon(
                  Icons.delete_outline,
                  color: Theme.of(context).colorScheme.error,
                ),
                title: Text(
                  'Remove API key',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
                onTap: () => _confirmClear(context),
              ),
          ],
        );
      },
    );
  }

  Future<void> _editKey(
    BuildContext context, {
    required bool configured,
  }) async {
    final settings = context.read<SettingsCubit>();
    final controller = TextEditingController();
    var obscure = true;

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(configured ? 'Replace API key' : 'Add API key'),
              content: TextField(
                controller: controller,
                autofocus: true,
                obscureText: obscure,
                autocorrect: false,
                enableSuggestions: false,
                keyboardType: TextInputType.visiblePassword,
                decoration: InputDecoration(
                  labelText: 'sk-ant-…',
                  hintText: configured
                      ? 'Paste a new key to replace the stored one'
                      : 'Paste your Anthropic API key',
                  suffixIcon: IconButton(
                    icon: Icon(
                      obscure ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () => setState(() => obscure = !obscure),
                  ),
                ),
                onSubmitted: (_) => Navigator.of(dialogContext).pop(true),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    final value = controller.text;
    controller.dispose();

    if (saved ?? false) {
      await settings.saveAnthropicApiKey(value);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              value.trim().isEmpty ? 'API key removed' : 'API key saved',
            ),
          ),
        );
      }
    }
  }

  Future<void> _confirmClear(BuildContext context) async {
    final settings = context.read<SettingsCubit>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove API key?'),
        content: const Text(
          'Voice extraction and the assistant will stop working until '
          'you add a key again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed ?? false) await settings.clearAnthropicApiKey();
  }
}
