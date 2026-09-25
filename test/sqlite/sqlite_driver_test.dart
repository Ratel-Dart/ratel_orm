import 'dart:async';
import 'dart:io';

import 'package:ratel_orm/ratel_orm.dart';
import 'package:ratel_orm/sqlite.dart';
import 'package:sqlite3/sqlite3.dart' show SqliteException;
import 'package:test/test.dart';

import '../support/driver_conformance.dart';
import '../support/fixtures/repositories/note_repository.dart';
import '../support/sqlite_test_library.dart';
import '../support/test_entities.dart';

void main() {
  setUpAll(SqliteTestLibrary.useSystemLibrary);
  TestEntities.install();

  test('in-memory CRUD via repository with @name params and returning',
      () async {
    final driver = SqliteDriver.memory();
    await driver.open();
    await driver
        .query('CREATE TABLE notes (id INTEGER PRIMARY KEY, body TEXT)');

    final notes = NoteRepository(driver);
    final inserted = await notes.add(1, 'hello');
    expect(inserted.single.id, 1);
    expect(inserted.single.body, 'hello');

    final all = await notes.findAll();
    expect(all.single.body, 'hello');
    await driver.close();
  });

  test('param-less SQL runs verbatim (@ left intact)', () async {
    final driver = SqliteDriver.memory();
    await driver.open();
    final result = await driver.query("SELECT '@x' AS v");
    expect(result.rows.single['v'], '@x');
    await driver.close();
  });

  test('transaction commits, and rolls back on error', () async {
    final driver = SqliteDriver.memory();
    await driver.open();
    await driver.query('CREATE TABLE t (id INTEGER PRIMARY KEY)');

    await driver.transaction((session) async {
      await session
          .query('INSERT INTO t (id) VALUES (@id)', parameters: {'id': 1});
      return session.query('SELECT 1');
    });
    var count = await driver.query('SELECT count(*) AS c FROM t');
    expect(count.rows.single['c'], 1);

    await expectLater(
      driver.transaction((session) async {
        await session
            .query('INSERT INTO t (id) VALUES (@id)', parameters: {'id': 2});
        throw StateError('boom');
      }),
      throwsA(isA<StateError>()),
    );
    count = await driver.query('SELECT count(*) AS c FROM t');
    expect(count.rows.single['c'], 1);
    await driver.close();
  });

  test('a SELECT after a write reports no affected rows and no insert id',
      () async {
    final driver = SqliteDriver.memory();
    await driver.open();
    await driver.query('CREATE TABLE t (id INTEGER PRIMARY KEY)');

    final insert = await driver
        .query('INSERT INTO t (id) VALUES (@id)', parameters: {'id': 7});
    expect(insert.affectedRows, 1);
    expect(insert.lastInsertId, 7);

    final select = await driver.query('SELECT id FROM t');
    expect(select.rows.single['id'], 7);
    expect(select.affectedRows, 0);
    expect(select.lastInsertId, isNull);

    final bound = await driver
        .query('SELECT id FROM t WHERE id = @id', parameters: {'id': 7});
    expect(bound.rows.single['id'], 7);
    expect(bound.affectedRows, 0);
    expect(bound.lastInsertId, isNull);
    await driver.close();
  });

  test('a driver query waits for an open transaction instead of joining it',
      () async {
    final driver = SqliteDriver.memory();
    await driver.open();
    await driver.query('CREATE TABLE t (id INTEGER PRIMARY KEY)');

    final entered = Completer<void>();
    final release = Completer<void>();
    final transaction = driver.transaction((session) async {
      await session.query('INSERT INTO t (id) VALUES (1)');
      entered.complete();
      await release.future;
      throw StateError('rollback');
    });
    await entered.future;

    final outside = driver.query('INSERT INTO t (id) VALUES (2)');
    release.complete();
    await expectLater(transaction, throwsA(isA<StateError>()));
    await outside;

    final ids = await driver.query('SELECT id FROM t ORDER BY id');
    expect([for (final row in ids.rows) row['id']], [2]);
    await driver.close();
  });

  test('a driver query made inside a transaction runs in it', () async {
    final driver = SqliteDriver.memory();
    await driver.open();
    await driver
        .query('CREATE TABLE notes (id INTEGER PRIMARY KEY, body TEXT)');
    final notes = NoteRepository(driver);

    final seen = await driver.transaction((session) async {
      await session.query("INSERT INTO notes (id, body) VALUES (1, 'draft')");
      return notes.findAll();
    }).timeout(const Duration(seconds: 5));

    expect(seen.single.body, 'draft');
    await driver.close();
  });

  test('a transaction begun after the outer one ended runs on its own',
      () async {
    final driver = SqliteDriver.memory();
    await driver.open();
    addTearDown(driver.close);
    await driver.query('CREATE TABLE t (id INTEGER PRIMARY KEY)');

    final ended = Completer<void>();
    late Future<void> afterwards;
    await driver.transaction((session) async {
      afterwards = ended.future.then((_) {
        return driver.transaction<void>((later) async {
          await later.query('INSERT INTO t (id) VALUES (1)');
          throw StateError('undo');
        });
      });
    });
    ended.complete();
    await expectLater(
      afterwards.timeout(const Duration(seconds: 5)),
      throwsStateError,
    );

    final count = await driver.query('SELECT count(*) AS c FROM t');
    expect(count.rows.single['c'], 0);
  });

  test('open wraps a native failure in DriverConnectionException', () async {
    final root = await Directory.systemTemp.createTemp('ratel_orm_sqlite_');
    addTearDown(() => root.delete(recursive: true));
    final separator = Platform.pathSeparator;
    final driver =
        SqliteDriver('${root.path}${separator}missing${separator}a.db');

    await expectLater(
      driver.open(),
      throwsA(isA<DriverConnectionException>().having(
        (e) => e.cause,
        'cause',
        isA<SqliteException>(),
      )),
    );
  });

  test('binds a DateTime as UTC ISO-8601 text', () async {
    final driver = SqliteDriver.memory();
    await driver.open();
    addTearDown(driver.close);
    await driver.query('CREATE TABLE t (at TEXT)');

    final instant = DateTime.utc(2024, 5, 6, 7, 8, 9, 10);
    await driver.query(
      'INSERT INTO t (at) VALUES (@at)',
      parameters: {'at': instant.toLocal()},
    );
    await driver.transaction((session) => session.query(
          'INSERT INTO t (at) VALUES (@at)',
          parameters: {'at': instant},
        ));

    final stored = await driver.query('SELECT at, typeof(at) AS kind FROM t');
    expect(stored.rows, [
      {'at': '2024-05-06T07:08:09.010000Z', 'kind': 'text'},
      {'at': '2024-05-06T07:08:09.010000Z', 'kind': 'text'},
    ]);
    expect(
      DateTime.parse(stored.rows.first['at']! as String),
      instant,
    );
  });

  test('binds a DateTime as text that sorts and compares in time order',
      () async {
    final driver = SqliteDriver.memory();
    await driver.open();
    addTearDown(driver.close);
    await driver.query('CREATE TABLE t (at TEXT)');

    final earlier = DateTime.utc(2024, 1, 1, 0, 0, 0, 8);
    final later = DateTime.utc(2024, 1, 1, 0, 0, 0, 8, 9);
    for (final at in [later, earlier, DateTime.utc(2023, 12, 31, 23)]) {
      await driver.query(
        'INSERT INTO t (at) VALUES (@at)',
        parameters: {'at': at},
      );
    }

    final ordered = await driver.query('SELECT at FROM t ORDER BY at');
    expect(
      [for (final row in ordered.rows) DateTime.parse(row['at']! as String)],
      [DateTime.utc(2023, 12, 31, 23), earlier, later],
    );

    final after = await driver.query(
      'SELECT at FROM t WHERE at > @since',
      parameters: {'since': earlier},
    );
    expect(after.rows, [
      {'at': '2024-01-01T00:00:00.008009Z'},
    ]);
  });

  test('binds a DateTime beyond four-digit years as parseable text', () async {
    final driver = SqliteDriver.memory();
    await driver.open();
    addTearDown(driver.close);

    for (final at in [DateTime.utc(12345, 6, 7), DateTime.utc(-12, 3, 4)]) {
      final result =
          await driver.query('SELECT @at AS at', parameters: {'at': at});
      expect(DateTime.parse(result.rows.single['at']! as String), at);
    }
  });

  test('binds a bool as 1 or 0', () async {
    final driver = SqliteDriver.memory();
    await driver.open();
    addTearDown(driver.close);

    final result = await driver.query(
      'SELECT @yes AS yes, @no AS no',
      parameters: {'yes': true, 'no': false},
    );
    expect(result.rows.single, {'yes': 1, 'no': 0});
  });

  test('wraps a parameter sqlite3 cannot bind in QueryExecutionException',
      () async {
    final driver = SqliteDriver.memory();
    await driver.open();
    addTearDown(driver.close);

    const sql = 'SELECT @value AS value';
    final unbindable = throwsA(isA<QueryExecutionException>()
        .having((error) => error.sql, 'sql', sql)
        .having((error) => error.cause, 'cause', isA<ArgumentError>()));
    await expectLater(
      driver.query(sql, parameters: {'value': const Duration(seconds: 1)}),
      unbindable,
    );
    await expectLater(
      driver.query(sql, parameters: {'value': 1, 'extra': 2}),
      unbindable,
    );
    await expectLater(
      driver.transaction((session) =>
          session.query(sql, parameters: {'value': Uri.parse('x:y')})),
      unbindable,
    );

    final after = await driver.query(sql, parameters: {'value': 1});
    expect(after.rows.single['value'], 1);
  });

  group('driver conformance', () {
    DriverConformance.run(SqliteDriver.memory);
    DriverConformance.parameters(SqliteDriver.memory);
    DriverConformance.nestedTransactions(SqliteDriver.memory);
  });
}
