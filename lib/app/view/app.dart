import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intellispendiq/app/app_services.dart';
import 'package:intellispendiq/app/cubit/cubit.dart';
import 'package:intellispendiq/app/theme/theme.dart';
import 'package:intellispendiq/auth/auth.dart';
import 'package:intellispendiq/data/repositories/account_repository.dart';
import 'package:intellispendiq/data/repositories/app_lock_repository.dart';
import 'package:intellispendiq/data/repositories/budget_repository.dart';
import 'package:intellispendiq/data/repositories/category_repository.dart';
import 'package:intellispendiq/data/repositories/income_repository.dart';
import 'package:intellispendiq/data/repositories/raw_capture_repository.dart';
import 'package:intellispendiq/data/repositories/settings_repository.dart';
import 'package:intellispendiq/data/repositories/transaction_repository.dart';
import 'package:intellispendiq/domain/services/capture_service.dart';
import 'package:intellispendiq/domain/services/finance_chat_service.dart';
import 'package:intellispendiq/domain/services/sms_sync_service.dart';
import 'package:intellispendiq/domain/voice/voice_pipeline.dart';
import 'package:intellispendiq/home/home.dart';

/// Root widget. Repositories and services are exposed with
/// [RepositoryProvider] so cubits resolve them from the tree rather
/// than being handed a god object.
class App extends StatelessWidget {
  const App({required this.services, super.key});

  final AppServices services;

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<AccountRepository>.value(value: services.accounts),
        RepositoryProvider<CategoryRepository>.value(
          value: services.categories,
        ),
        RepositoryProvider<TransactionRepository>.value(
          value: services.transactions,
        ),
        RepositoryProvider<RawCaptureRepository>.value(
          value: services.rawCaptures,
        ),
        RepositoryProvider<BudgetRepository>.value(value: services.budgets),
        RepositoryProvider<IncomeRepository>.value(value: services.income),
        RepositoryProvider<SettingsRepository>.value(value: services.settings),
        RepositoryProvider<CaptureService>.value(
          value: services.captureService,
        ),
        RepositoryProvider<SmsSyncService>.value(value: services.smsSync),
        RepositoryProvider<VoicePipeline>.value(value: services.voicePipeline),
        RepositoryProvider<FinanceChatService>.value(
          value: services.financeChat,
        ),
        RepositoryProvider<AppLockRepository>.value(value: services.appLock),
      ],
      // Theme, auth and deep links are app-wide, so they sit above the
      // MaterialApp rather than inside any one screen.
      child: MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (_) => ThemeCubit(services.settings)..loadUnawaited(),
          ),
          BlocProvider(create: (_) => AuthCubit(services.appLock)),
          BlocProvider(
            create: (_) =>
                DeepLinkCubit(services.deepLinkSource)..startUnawaited(),
          ),
        ],
        child: BlocBuilder<ThemeCubit, ThemeMode>(
          builder: (context, themeMode) {
            return MaterialApp(
              title: services.flavor.displayName,
              theme: AppTheme.light,
              darkTheme: AppTheme.dark,
              themeMode: themeMode,
              home: const AuthGate(child: HomePage()),
            );
          },
        ),
      ),
    );
  }
}

/// Shown when the encrypted database cannot be opened. Failing loudly
/// beats falling back to an unencrypted store.
class StartupFailure extends StatelessWidget {
  const StartupFailure({required this.error, super.key});

  final String error;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline, size: 48),
                const SizedBox(height: 16),
                const Text(
                  'Could not open the encrypted database',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(error, textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
