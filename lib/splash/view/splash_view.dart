import 'package:flutter/material.dart';
import 'package:intellispendiq/design/components/app_icon.dart';
import 'package:intellispendiq/design/theme/app_theme.dart';
import 'package:intellispendiq/design/tokens/icons.dart';

/// The first thing drawn, in two situations: while the encrypted
/// database is being opened, and while the auth status is still
/// unresolved.
///
/// It is a plain widget rather than a page so both callers can use it —
/// one of them has no [Navigator] yet.
class SplashView extends StatelessWidget {
  const SplashView({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colors.surface,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppIcon(AppIcons.budgets, size: 72, color: colors.primary),
            const SizedBox(height: 20),
            Text(
              'IntelliSpendIQ',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: colors.onSurface,
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: colors.primary,
              ),
            ),
            if (message != null) ...[
              const SizedBox(height: 16),
              Text(
                message!,
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A standalone app wrapper for [SplashView].
///
/// `bootstrap` runs this before `AppServices` exists, so that SQLCipher
/// key derivation happens behind branding instead of a blank window.
/// It cannot read the user's saved theme — that lives in the database
/// this screen is waiting on — so it follows the system brightness.
class SplashApp extends StatelessWidget {
  const SplashApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'IntelliSpendIQ',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      debugShowCheckedModeBanner: false,
      home: const SplashView(),
    );
  }
}
