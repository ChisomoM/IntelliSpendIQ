import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intellispendiq/data/db/app_database.dart';

void main() {
  test(
    'a v15 database without shopping tables gains them on upgrade',
    () async {
      final dir = await Directory.systemTemp.createTemp('shopping_migration_');
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/app.db');

      final first = AppDatabase(NativeDatabase(file));
      await first.customSelect('SELECT 1').get();
      await first.customStatement('DROP TABLE shopping_trip_items');
      await first.customStatement('DROP TABLE shopping_trips');
      await first.customStatement('PRAGMA user_version = 15');
      await first.close();

      final second = AppDatabase(NativeDatabase(file));
      addTearDown(second.close);
      final rows = await second
          .customSelect(
            "SELECT name FROM sqlite_master WHERE name LIKE 'shopping_trip%'",
          )
          .get();

      expect(
        rows.map((r) => r.read<String>('name')),
        containsAll(['shopping_trips', 'shopping_trip_items']),
      );
    },
  );
}
