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
import 'package:intellispendiq/design/design.dart';
import 'package:intellispendiq/domain/services/backup_service.dart';
import 'package:intellispendiq/domain/services/data_reset_service.dart';
import 'package:intellispendiq/domain/services/sms_sync_service.dart';
import 'package:intellispendiq/licensing/cubit/cubit.dart';
import 'package:intellispendiq/licensing/entitlement.dart';
import 'package:intellispendiq/licensing/view/payment_instructions.dart';
import 'package:intellispendiq/senders/senders.dart';
import 'package:intellispendiq/settings/budget_cadence_labels.dart';
import 'package:intellispendiq/settings/cubit/cubit.dart';
import 'package:intellispendiq/settings/view/budget_cycle_page.dart';
import 'package:intellispendiq/settings/view/reminder_settings_page.dart';
import 'package:share_plus/share_plus.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  static Route<void> route() {
    return MaterialPageRoute<void>(builder: (_) => const SettingsPage());
  }

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
        padding: const EdgeInsets.fromLTRB(
          Space.gutter,
          Space.x1,
          Space.gutter,
          Space.x4,
        ),
        children: const [
          _SectionLabel('Account'),
          _AccountSection(),
          SizedBox(height: Space.sectionGap),
          _SectionLabel('Appearance'),
          _ThemeSelector(),
          SizedBox(height: Space.sectionGap),
          _SectionLabel('Money'),
          _MoneySection(),
          SizedBox(height: Space.sectionGap),
          _SectionLabel('Notifications'),
          _NotificationsSection(),
          SizedBox(height: Space.sectionGap),
          _SectionLabel('Data'),
          _DataSection(),
          SizedBox(height: Space.sectionGap),
          _SectionLabel('Security'),
          _AppLockSection(),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, Space.x1),
      child: Text(
        title,
        style: AppTypography.chipOverline(
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}

/// Groups a fixed list of rows into one [AppCard], each separated by a
/// hairline — the shape every settings section below uses so the screen
/// reads as a stack of cards rather than a single long list.
class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.rows});

  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) Divider(height: 1, color: colors.outlineVariant),
            rows[i],
          ],
        ],
      ),
    );
  }
}

class _AccountSection extends StatelessWidget {
  const _AccountSection();

  @override
  Widget build(BuildContext context) {
    final email = context.select<IdentityCubit, String>(
      (c) => c.state.user?.email ?? 'Not signed in',
    );
    final status = context.select<EntitlementCubit, EntitlementStatus>(
      (c) => c.state.status,
    );
    final licenseLabel = switch (status) {
      EntitlementStatus.trial => 'Trial active',
      EntitlementStatus.grace => 'Grace period',
      EntitlementStatus.active => 'Subscription active',
      EntitlementStatus.disabled => 'Disabled',
      EntitlementStatus.blocked => 'Blocked',
      EntitlementStatus.unknown => 'Unknown',
    };

    return _SettingsGroup(
      rows: [
        ListTile(
          title: const Text('Signed in as'),
          subtitle: Text(email),
        ),
        ListTile(
          title: const Text('License'),
          subtitle: Text(licenseLabel),
          trailing: TextButton(
            onPressed: () => showPaywallModal(
              context,
              canDismiss: EntitlementEvaluator.canDismissPaywall(status),
            ),
            child: const Text('Pay'),
          ),
        ),
        ListTile(
          title: const Text('Refresh license'),
          trailing: const Icon(Icons.refresh),
          onTap: () => context.read<EntitlementCubit>().refreshUnawaited(),
        ),
        ListTile(
          title: Text(
            'Sign out',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
          onTap: () async {
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Sign out?'),
                content: const Text(
                  'You will need to sign in again. Your local data stays on '
                  'this device.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Sign out'),
                  ),
                ],
              ),
            );
            if (confirmed != true || !context.mounted) return;
            final identity = context.read<IdentityCubit>();
            final entitlement = context.read<EntitlementCubit>();
            final navigator = Navigator.of(context);
            await identity.signOut();
            await entitlement.signOut();
            navigator.pop();
          },
        ),
      ],
    );
  }
}

class _ThemeSelector extends StatelessWidget {
  const _ThemeSelector();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ThemeCubit, ThemeMode>(
      builder: (context, mode) {
        return AppCard(
          child: Row(
            children: [
              for (final option in ThemeMode.values) ...[
                if (option != ThemeMode.values.first)
                  const SizedBox(width: Space.x1),
                Expanded(child: _ThemeOption(option: option, selected: option == mode)),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _ThemeOption extends StatelessWidget {
  const _ThemeOption({required this.option, required this.selected});

  final ThemeMode option;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final icon = switch (option) {
      ThemeMode.light => AppIcons.sun,
      ThemeMode.dark => AppIcons.moon,
      ThemeMode.system => AppIcons.settings,
    };

    return Material(
      color: selected ? colors.primary.withValues(alpha: 0.10) : Colors.transparent,
      borderRadius: Radii.inputRadius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.read<ThemeCubit>().setThemeModeUnawaited(option),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: Space.x2),
          child: Column(
            children: [
              AppIcon(
                icon,
                size: 20,
                color: selected ? colors.primary : colors.onSurfaceVariant,
              ),
              const SizedBox(height: 4),
              Text(
                _label(option),
                style: AppTypography.metadata(
                  color: selected ? colors.primary : colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _label(ThemeMode mode) => switch (mode) {
    ThemeMode.system => 'System',
    ThemeMode.light => 'Light',
    ThemeMode.dark => 'Dark',
  };
}

class _MoneySection extends StatelessWidget {
  const _MoneySection();

  @override
  Widget build(BuildContext context) {
    return _SettingsGroup(
      rows: [
        AppListRow(
          leading: _RowIcon(icon: AppIcons.calendar),
          title: const Text('Budget cycle'),
          subtitle: const _BudgetCycleSubtitle(),
          trailing: _Chevron(),
          onTap: () =>
              Navigator.of(context).push<void>(BudgetCyclePage.route()),
        ),
        AppListRow(
          leading: _RowIcon(icon: AppIcons.accountBank),
          title: const Text('Accounts'),
          subtitle: const Text('Manage cash, bank, and mobile money accounts'),
          trailing: _Chevron(),
          onTap: () => Navigator.of(context).push<void>(AccountsPage.route()),
        ),
        AppListRow(
          leading: _RowIcon(icon: AppIcons.budgets),
          title: const Text('Categories'),
          subtitle: const Text('Add or remove spending categories'),
          trailing: _Chevron(),
          onTap: () => Navigator.of(context).push<void>(CategoriesPage.route()),
        ),
        AppListRow(
          leading: _RowIcon(icon: AppIcons.senders),
          title: const Text('Message senders'),
          subtitle: const Text("Recognize another bank or wallet's SMS alerts"),
          trailing: _Chevron(),
          onTap: () =>
              Navigator.of(context).push<void>(CustomSendersPage.route()),
        ),
      ],
    );
  }
}

class _NotificationsSection extends StatelessWidget {
  const _NotificationsSection();

  @override
  Widget build(BuildContext context) {
    return _SettingsGroup(
      rows: [
        AppListRow(
          leading: _RowIcon(icon: AppIcons.calendar),
          title: const Text('Reminders'),
          subtitle: const Text('Nudges to log expenses on days you forget'),
          trailing: _Chevron(),
          onTap: () =>
              Navigator.of(context).push<void>(ReminderSettingsPage.route()),
        ),
      ],
    );
  }
}

class _RowIcon extends StatelessWidget {
  const _RowIcon({required this.icon, this.color});

  final List<List<dynamic>> icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final tone = color ?? colors.primary;

    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.10),
        borderRadius: Radii.inputRadius,
      ),
      alignment: Alignment.center,
      child: AppIcon(icon, size: 18, color: tone),
    );
  }
}

class _Chevron extends StatelessWidget {
  const _Chevron();

  @override
  Widget build(BuildContext context) {
    return AppIcon(
      AppIcons.chevronRight,
      size: 18,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
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

class _AppLockSection extends StatelessWidget {
  const _AppLockSection();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return BlocBuilder<SettingsCubit, SettingsState>(
      builder: (context, state) {
        if (state.status == SettingsStatus.initial) {
          return const AppCard(
            child: Center(
              heightFactor: 2,
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (!state.pinSet) {
          return _SettingsGroup(
            rows: [
              AppListRow(
                leading: const _RowIcon(icon: AppIcons.lock),
                title: const Text('Set up app lock'),
                subtitle: const Text(
                  'Require a PIN to open IntelliSpendIQ. Capture keeps '
                  'running while locked.',
                ),
                trailing: const _Chevron(),
                onTap: () => _setUpPin(context),
              ),
            ],
          );
        }

        return _SettingsGroup(
          rows: [
            AppListRow(
              leading: const _RowIcon(icon: AppIcons.lock),
              title: const Text('Change PIN'),
              trailing: const _Chevron(),
              onTap: () => _setUpPin(context, requireCurrentPin: true),
            ),
            if (state.biometricsAvailable)
              AppListRow(
                leading: const _RowIcon(icon: AppIcons.fingerprint),
                title: const Text('Unlock with biometrics'),
                trailing: Switch(
                  value: state.biometricsEnabled,
                  onChanged: (enabled) => _setBiometrics(context, enabled),
                ),
              ),
            AppListRow(
              leading: const _RowIcon(icon: AppIcons.lock),
              title: const Text('Lock now'),
              onTap: context.read<AuthCubit>().lockUnawaited,
            ),
            AppListRow(
              leading: _RowIcon(icon: AppIcons.close, color: colors.error),
              title: Text('Turn off app lock', style: TextStyle(color: colors.error)),
              onTap: () => _confirmDisable(context),
            ),
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
        _SettingsGroup(
          rows: [
            AppListRow(
              leading: const _RowIcon(icon: AppIcons.exportData),
              title: const Text('Export transactions (CSV)'),
              subtitle: const Text('For your own records or a spreadsheet'),
              onTap: _busy ? null : () => _exportCsv(context),
            ),
            AppListRow(
              leading: const _RowIcon(icon: AppIcons.backup),
              title: const Text('Back up all data (JSON)'),
              subtitle: const Text(
                'Accounts, categories, budgets, and transactions',
              ),
              onTap: _busy ? null : () => _exportBackup(context),
            ),
            AppListRow(
              leading: const _RowIcon(icon: AppIcons.restore),
              title: const Text('Restore from backup'),
              subtitle: const Text(
                "Adds a backup file's data to what is already here",
              ),
              onTap: _busy ? null : () => _restoreBackup(context),
            ),
            AppListRow(
              leading: const _RowIcon(icon: AppIcons.senders),
              title: const Text('Rescan SMS inbox'),
              subtitle: const Text(
                'Re-checks the last 30 days for a sender you just added',
              ),
              trailing: const Icon(Icons.refresh),
              onTap: _busy ? null : () => _rescanSms(context),
            ),
          ],
        ),
        const SizedBox(height: Space.x2),
        _SettingsGroup(
          rows: [
            AppListRow(
              leading: _RowIcon(
                icon: AppIcons.close,
                color: Theme.of(context).colorScheme.error,
              ),
              title: Text(
                'Reset all data',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              subtitle: const Text(
                'Erases every account, transaction, and budget on this '
                'device and starts fresh from today',
              ),
              onTap: _busy ? null : () => _resetAllData(context),
            ),
          ],
        ),
        if (_busy)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: Space.x2),
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

  Future<void> _resetAllData(BuildContext context) async {
    final dataReset = context.read<DataResetService>();
    final messenger = ScaffoldMessenger.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reset all data?'),
        content: const Text(
          'This permanently erases every account, category, budget, and '
          'transaction on this device. It cannot be undone — back up '
          'first if you want to keep a copy. From this point on, only '
          'new SMS and entries you make from now are tracked; nothing '
          'older is re-imported.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Reset everything'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    setState(() => _busy = true);
    try {
      await dataReset.resetAllData();
      messenger.showSnackBar(
        const SnackBar(content: Text('All data reset. Starting fresh.')),
      );
    } on Exception catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('Could not reset data: $error')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _rescanSms(BuildContext context) async {
    final smsSync = context.read<SmsSyncService>();
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      final ingested = await smsSync.rescan();
      messenger.showSnackBar(
        SnackBar(content: Text('Rescan found $ingested new message(s).')),
      );
    } on Exception catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('Could not rescan: $error')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
