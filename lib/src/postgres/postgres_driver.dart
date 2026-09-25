import 'dart:async';
import 'dart:io';

import 'package:postgres/postgres.dart';

import '../dialect/postgres_dialect.dart';
import '../dialect/sql_dialect.dart';
import '../driver/query_result.dart';
import '../driver/ratel_driver.dart';
import '../driver/ratel_session.dart';
import '../exceptions/database_exception.dart';
import '../exceptions/query_execution_exception.dart';
import 'postgres_parameters.dart';
import 'postgres_result_mapper.dart';
import 'postgres_session.dart';
import 'ssl_mode_parser.dart';

class PostgresDriver extends RatelDriver {
  final String host;

  final int port;

  final String databaseName;

  final String username;

  final String password;

  final SslMode sslMode;

  final int maxConnections;

  Pool? _pool;

  final Object _transaction = Object();

  PostgresDriver({
    required this.host,
    this.port = 5432,
    required this.databaseName,
    required this.username,
    required this.password,
    this.sslMode = SslMode.require,
    this.maxConnections = 10,
  });

  factory PostgresDriver.fromEnv() {
    final env = Platform.environment;

    String required(String key) {
      final value = env[key];
      if (value == null || value.isEmpty) {
        throw StateError('Missing required environment variable: $key');
      }
      return value;
    }

    final port = int.tryParse(env['DB_PORT'] ?? '5432');
    if (port == null) {
      throw StateError('Invalid DB_PORT: "${env['DB_PORT']}"');
    }

    final poolMax = int.tryParse(env['DB_POOL_MAX'] ?? '10');
    if (poolMax == null) {
      throw StateError('Invalid DB_POOL_MAX: "${env['DB_POOL_MAX']}"');
    }

    return PostgresDriver(
      host: required('DB_HOST'),
      port: port,
      databaseName: required('DB_NAME'),
      username: required('DB_USER'),
      password: required('DB_PASSWORD'),
      sslMode: SslModeParser.parse(env['DB_SSL_MODE']),
      maxConnections: poolMax,
    );
  }

  Endpoint get _endpoint => Endpoint(
        host: host,
        database: databaseName,
        username: username,
        password: password,
        port: port,
      );

  PoolSettings get _poolSettings => PoolSettings(
        sslMode: sslMode,
        maxConnectionCount: maxConnections,
      );

  @override
  SqlDialect get dialect => const PostgresDialect();

  @override
  Future<void> open() async =>
      _pool ??= Pool.withEndpoints([_endpoint], settings: _poolSettings);

  @override
  Future<void> close() async {
    await _pool?.close();
    _pool = null;
  }

  Future<Pool> get _openPool async {
    await open();
    return _pool!;
  }

  PostgresSession? get _openSession {
    final session = Zone.current[_transaction];
    return session is PostgresSession && session.isOpen ? session : null;
  }

  @override
  Future<QueryResult> query(String sql,
      {Map<String, Object?>? parameters}) async {
    final session = _openSession;
    if (session != null) {
      return session.query(sql, parameters: parameters);
    }
    final pool = await _openPool;
    try {
      final result = (parameters == null || parameters.isEmpty)
          ? await pool.execute(sql)
          : await pool.execute(
              Sql.named(sql),
              parameters: PostgresParameters.bindable(parameters),
            );
      return PostgresResultMapper.toQueryResult(result);
    } on DatabaseException {
      rethrow;
    } catch (e) {
      throw QueryExecutionException('Postgres query failed',
          sql: sql, cause: e);
    }
  }

  @override
  Future<T> transaction<T>(
    Future<T> Function(RatelSession session) action,
  ) async {
    final open = _openSession;
    if (open != null) return action(open);
    final pool = await _openPool;
    String? statement = 'BEGIN';
    try {
      return await pool.runTx((tx) async {
        statement = null;
        final session = PostgresSession(tx);
        final result = await runZoned(
          () => action(session),
          zoneValues: {_transaction: session},
        );
        statement = 'COMMIT';
        return result;
      });
    } catch (e) {
      final failed = statement;
      if (failed == null) rethrow;
      throw QueryExecutionException(
        'Postgres transaction failed',
        sql: failed,
        cause: e,
      );
    }
  }
}
