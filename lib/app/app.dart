import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intellispendiq/app/app_services.dart';
import 'package:intellispendiq/app/theme.dart';
import 'package:intellispendiq/features/home/home_page.dart';

class IntelliSpendApp extends StatefulWidget {
  const IntelliSpendApp({required this.services, super.key});

  final AppServices services;

  @override
  State<IntelliSpendApp> createState() => _IntelliSpendAppState();
}

class _IntelliSpendAppState extends State<IntelliSpendApp> {
  @override
  void dispose() {
    // Fire and forget: the process is going away regardless.
    unawaited(widget.services.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      services: widget.services,
      child: MaterialApp(
        title: 'IntelliSpendIQ',
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        home: const HomePage(),
      ),
    );
  }
}

/// Makes [AppServices] available to the widget tree.
class AppScope extends InheritedWidget {
  const AppScope({required this.services, required super.child, super.key});

  final AppServices services;

  static AppServices of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope not found in widget tree');
    return scope!.services;
  }

  @override
  bool updateShouldNotify(AppScope oldWidget) => services != oldWidget.services;
}

/// Shown when the encrypted database cannot be opened. Failing loudly
/// beats falling back to an unencrypted store.
class StartupFailureApp extends StatelessWidget {
  const StartupFailureApp({required this.error, super.key});

  final String error;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: AppTheme.light(),
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
