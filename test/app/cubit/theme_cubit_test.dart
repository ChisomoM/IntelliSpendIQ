import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intellispendiq/app/app_services.dart';
import 'package:intellispendiq/app/cubit/cubit.dart';

import '../../support/test_harness.dart';

void main() {
  late AppServices services;

  setUp(() async => services = await createTestServices());
  tearDown(() async => services.dispose());

  group('ThemeCubit', () {
    test('follows the system until told otherwise', () {
      final cubit = ThemeCubit(services.settings);
      addTearDown(cubit.close);

      expect(cubit.state, ThemeMode.system);
    });

    blocTest<ThemeCubit, ThemeMode>(
      'applies a choice immediately',
      build: () => ThemeCubit(services.settings),
      act: (cubit) => cubit.setThemeMode(ThemeMode.dark),
      expect: () => [ThemeMode.dark],
    );

    test('remembers the choice across a restart', () async {
      final first = ThemeCubit(services.settings);
      await first.setThemeMode(ThemeMode.dark);
      await first.close();

      // A fresh cubit over the same store stands in for a relaunch.
      final second = ThemeCubit(services.settings);
      addTearDown(second.close);
      await second.load();

      expect(second.state, ThemeMode.dark);
    });

    blocTest<ThemeCubit, ThemeMode>(
      'stays on system when nothing was ever saved',
      build: () => ThemeCubit(services.settings),
      act: (cubit) => cubit.load(),
      // Bloc lets the first emit through even when it equals the
      // initial state, so this is one emission rather than none.
      expect: () => [ThemeMode.system],
    );

    test('falls back to system on an unreadable stored value', () async {
      await services.settings.set(ThemeCubit.settingsKey, 'ultraviolet');

      final cubit = ThemeCubit(services.settings);
      addTearDown(cubit.close);
      await cubit.load();

      expect(
        cubit.state,
        ThemeMode.system,
        reason: 'A junk setting must not leave the app themeless',
      );
    });

    test('round-trips every mode', () async {
      for (final mode in ThemeMode.values) {
        final writer = ThemeCubit(services.settings);
        await writer.setThemeMode(mode);
        await writer.close();

        final reader = ThemeCubit(services.settings);
        await reader.load();
        expect(reader.state, mode);
        await reader.close();
      }
    });
  });
}
