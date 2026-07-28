import 'package:c_template_app/utils/database_scripts.dart';

enum AppEnv { development, staging, production }

/// {@template config}
/// Config description
/// {@endtemplate}
class Config {
  /// {@macro config}
  const Config({
    required this.baseUrl,
    // required this.socketUrl,
    required this.dbName,
    required this.host,
    required this.initScript,
    this.environment = AppEnv.development,
    this.migrations = const [],
    this.uuid,
  });

  /// Creates a dev config
  factory Config.dev() => Config(
    baseUrl: 'http://155.138.220.54:3000/api/',
    // socketUrl: 'ws://155.138.220.54/api_socket/websocket?vsn=2.0.0',
    host: '155.138.220.54',
    dbName: 'tariff.comparator.dev.db',
    initScript: initialScript,
    migrations: migrationScript,
  );

  /// Creates a staging config
  factory Config.staging() => Config(
    environment: AppEnv.staging,
    baseUrl: 'http://155.138.220.54:3000/api/',
    // socketUrl: 'ws://155.138.220.54/api_socket/websocket?vsn=2.0.0',
    host: '155.138.220.54',
    dbName: 'tariff.comparator.stg.db',
    initScript: initialScript,
    migrations: migrationScript,
  );

  /// Creates a production config
  factory Config.prod() => Config(
    environment: AppEnv.production,
    baseUrl: 'http://155.138.220.54:3000/api/',
    // socketUrl: 'ws://155.138.220.54/api_socket/websocket?vsn=2.0.0',
    host: '155.138.220.54',
    dbName: 'tariff.comparator.db',
    initScript: initialScript,
    migrations: migrationScript,
  );

  /// A description for baseUrl
  final String baseUrl;

  /// A description for socketUrl
  // final String socketUrl;

  /// A description for dbName
  final String dbName;

  /// A description for host
  final String host;

  /// A description for initScript
  final List<String> initScript;

  /// A description for migrations
  final List<String> migrations;

  /// A description for uuid
  final String? uuid;

  /// A description for environment
  final AppEnv environment;
}
