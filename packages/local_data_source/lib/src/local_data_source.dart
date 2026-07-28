import 'dart:developer';

import 'package:local_data_source/src/models/json_map.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_migration/sqflite_migration.dart';

/// {@template local_data_source}
/// A package to handle local data persistence via a sqlite database.
/// {@endtemplate}
class LocalDataSource {
  /// {@macro local_data_source}
  LocalDataSource._();

  /// Public factory
  static Future<LocalDataSource> init({
    required String dbName,
    required List<String> initialScript,
    List<String> migrations = const [],
  }) async {
    final dataApi = LocalDataSource._();
    await dataApi._init(dbName, initialScript, migrations);
    return dataApi;
  }

  late Database _database;

  Future<void> _init(
    String dbName,
    List<String> initialScript,
    List<String> migrations,
  ) async {
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, dbName);

    final config = MigrationConfig(
      initializationScript: initialScript,
      migrationScripts: migrations,
    );
    _database = await openDatabaseWithMigration(path, config);
  }

  /// Inserts one [data] element into the table [tableName] and returns the
  /// [data] element with the inserted id.
  Future<JsonMap> insertOne(String tableName, JsonMap data) async {
    data['id'] = await _database.insert(
      tableName,
      data,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return data;
  }

  /// Inserts all elements in [data] list into the table [tableName].
  Future<void> insertAll(
    String tableName,
    List<dynamic> data, {
    bool delete = true,
  }) async {
    log('$tableName => Received ${data.length} rows');
    final batch = _database.batch();
    if (delete) batch.delete(tableName);
    for (final element in data) {
      batch.insert(
        tableName,
        element as JsonMap,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    final result = await batch.commit();
    log('$tableName => Inserted ${result.length} rows');
  }

  /// Get one element from the table [tableName] with the provided [id].
  /// If element with [id] doesn't exist, return null.
  Future<JsonMap?> getOne(
    String tableName,
    int id, {
    String field = 'id',
  }) async {
    final List<JsonMap> maps =
        await _database.query(tableName, where: '$field = ?', whereArgs: [id]);
    if (maps.isNotEmpty) {
      return maps.first;
    }
    return null;
  }

  /// Get [limit] elements from the table [tableName]. If [limit] is null, gets
  /// all elements from the table [tableName].
  Future<List<JsonMap>> getAll(
    String tableName, {
    int? limit,
    String? orderBy,
  }) async {
    final List<JsonMap> maps = await _database.query(
      tableName,
      limit: limit,
      orderBy: orderBy,
    );
    return maps;
  }

  /// Get [limit] elements from the table [tableName]. If [limit] is null, gets
  /// all elements from the table [tableName].
  Future<List<JsonMap>> getWhere(
    String tableName, {
    required String column,
    required String value,
    int? limit,
    String? orderBy,
  }) async {
    final List<JsonMap> maps = await _database.query(
      tableName,
      where: '$column = ?',
      whereArgs: [value],
      limit: limit,
      orderBy: orderBy,
    );
    return maps;
  }

  /// Delete one element from the table [tableName] with the provided [id].
  Future<int> deleteOne(String tableName, int id, {String field = 'id'}) async {
    return _database.delete(tableName, where: '$field = ?', whereArgs: [id]);
  }

  /// Delete all elements from the table [tableName].
  Future<int> deleteAll(String tableName) async {
    return _database.delete(tableName);
  }

  /// Update one element from the table [tableName] with the provided [data].
  Future<int> updateOne(
    String tableName,
    JsonMap data, {
    String field = 'id',
  }) async {
    return _database
        .update(tableName, data, where: '$field = ?', whereArgs: [data['id']]);
  }

  /// Update elements from the table [tableName] with the provided [data] where
  /// [column] = [value].
  Future<int> updateWhere(
    String tableName, {
    required String column,
    required String value,
    required JsonMap data,
  }) async {
    return _database.update(
      tableName,
      data,
      where: '$column = ?',
      whereArgs: [value],
    );
  }

  /// Update elements from the table [tableName] with the provided [data] where
  /// [column] = [value]. If the row doesn't exist in the table, insert the data
  /// in a new row.
  Future<void> insertOrUpdate(
    String tableName, {
    required String column,
    required String value,
    required JsonMap data,
  }) async {
    final count = await _database.update(
      tableName,
      data,
      where: '$column = ?',
      whereArgs: [value],
    );
    if (count < 1) {
      await _database.insert(
        tableName,
        data,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }
}
