import 'dart:async';

import 'package:ratel_orm/ratel_orm.dart';
import 'package:test/test.dart';

abstract final class DriverConformance {
  static const Duration _slow = Duration(seconds: 5);

  static void run(
    RatelDriver Function() create, {
    String probeQuery = 'SELECT 1',
  }) {
    group('RatelDriver conformance', () {
      test('open is idempotent', () async {
        final driver = create();
        await driver.open();
        await driver.open();
        await driver.close();
      });

      test('query returns a QueryResult', () async {
        final driver = create();
        await driver.open();
        final result = await driver.query(probeQuery);
        expect(result, isA<QueryResult>());
        expect(result.rows, isA<List<Map<String, Object?>>>());
        await driver.close();
      });

      test('transaction runs the action and returns its value', () async {
        final driver = create();
        await driver.open();
        final result = await driver.transaction(
          (session) => session.query(probeQuery),
        );
        expect(result, isA<QueryResult>());
        await driver.close();
      });

      test('a nested transaction joins the session of the outer one', () async {
        final driver = create();
        await driver.open();
        addTearDown(driver.close);
        final (joined, result) = await driver.transaction((outer) async {
          return driver.transaction((inner) async {
            return (identical(inner, outer), await inner.query(probeQuery));
          });
        }).timeout(_slow);
        expect(joined, isTrue);
        expect(result, isA<QueryResult>());
      });
    });
  }

  static void nestedTransactions(RatelDriver Function() create) {
    group('RatelDriver nested transaction conformance', () {
      const table = 'ratel_nested_tx';
      const insert = 'INSERT INTO $table (id) VALUES (@id)';
      const count = 'SELECT count(*) AS total FROM $table';
      late RatelDriver driver;

      setUp(() async {
        driver = create();
        await driver.open();
        await driver.query('DROP TABLE IF EXISTS $table');
        await driver.query('CREATE TABLE $table (id integer PRIMARY KEY)');
      });

      tearDown(() async {
        await driver.query('DROP TABLE IF EXISTS $table');
        await driver.close();
      });

      Future<List<Object?>> storedIds() async {
        final result = await driver.query('SELECT id FROM $table ORDER BY id');
        return [for (final row in result.rows) row['id']];
      }

      test('a nested transaction sees the outer writes and shares its own',
          () async {
        final (inside, outside) = await driver.transaction((outer) async {
          await outer.query(insert, parameters: {'id': 1});
          final inside = await driver.transaction((inner) async {
            final seen = await inner.query(count);
            await inner.query(insert, parameters: {'id': 2});
            return seen.rows.single['total'];
          });
          final outside = await outer.query(count);
          return (inside, outside.rows.single['total']);
        }).timeout(_slow);
        expect(inside, 1);
        expect(outside, 2);
        expect(await storedIds(), [1, 2]);
      });

      test('a failing nested transaction rolls back the outer writes',
          () async {
        final error = StateError('inner');
        await expectLater(
          driver.transaction<void>((outer) async {
            await outer.query(insert, parameters: {'id': 1});
            await driver.transaction<void>((inner) async {
              await inner.query(insert, parameters: {'id': 2});
              throw error;
            });
          }).timeout(_slow),
          throwsA(same(error)),
        );
        expect(await storedIds(), isEmpty);
      });

      test('a nested failure the outer action catches does not stop the commit',
          () async {
        final caught = await driver.transaction((outer) async {
          await outer.query(insert, parameters: {'id': 1});
          try {
            await driver.transaction<void>((inner) async {
              await inner.query(insert, parameters: {'id': 2});
              throw StateError('inner');
            });
          } on StateError catch (error) {
            return error.message;
          }
          return null;
        }).timeout(_slow);
        expect(caught, 'inner');
        expect(await storedIds(), [1, 2]);
      });

      test('a failing outer transaction rolls back the nested writes',
          () async {
        final error = StateError('outer');
        await expectLater(
          driver.transaction<void>((outer) async {
            await driver.transaction(
              (inner) => inner.query(insert, parameters: {'id': 1}),
            );
            await outer.query(insert, parameters: {'id': 2});
            throw error;
          }).timeout(_slow),
          throwsA(same(error)),
        );
        expect(await storedIds(), isEmpty);
      });

      test('nested transactions and driver queries do not wait on the outer',
          () async {
        final total = await driver.transaction((first) {
          return driver.transaction((second) {
            return driver.transaction((third) async {
              await driver.query(insert, parameters: {'id': 1});
              await third.query(insert, parameters: {'id': 2});
              final result = await first.query(count);
              return result.rows.single['total'];
            });
          });
        }).timeout(_slow);
        expect(total, 2);
        expect(await storedIds(), [1, 2]);
      });

      test('a query that outlives its transaction does not join a later one',
          () async {
        final ended = Completer<void>();
        late Future<QueryResult> afterwards;
        await driver.transaction((session) async {
          afterwards = ended.future.then(
            (_) => driver.query(insert, parameters: {'id': 1}),
          );
        }).timeout(_slow);

        final entered = Completer<void>();
        final release = Completer<void>();
        final other = driver.transaction<void>((session) async {
          await session.query(count);
          entered.complete();
          await release.future;
          throw StateError('undo');
        });
        await entered.future.timeout(_slow);
        ended.complete();
        await Future<void>.delayed(const Duration(milliseconds: 50));
        release.complete();
        await expectLater(other.timeout(_slow), throwsStateError);
        await afterwards.timeout(_slow);
        expect(await storedIds(), [1]);
      });
    });
  }

  static void parameters(RatelDriver Function() create) {
    group('RatelDriver parameter conformance', () {
      const echo = 'SELECT @value AS value';
      final instant = DateTime.utc(2024, 5, 6, 7, 8, 9, 10);
      late RatelDriver driver;

      setUp(() async {
        driver = create();
        await driver.open();
      });

      tearDown(() => driver.close());

      void expectInstant(Object? value) {
        final read =
            value is DateTime ? value : DateTime.parse(value! as String);
        expect(read.isAtSameMomentAs(instant), isTrue);
      }

      test('a DateTime parameter reads back as the same instant', () async {
        final result =
            await driver.query(echo, parameters: {'value': instant.toLocal()});
        expectInstant(result.rows.single['value']);
      });

      test('a transaction session binds a DateTime parameter too', () async {
        final result = await driver.transaction(
          (session) => session.query(echo, parameters: {'value': instant}),
        );
        expectInstant(result.rows.single['value']);
      });

      test('a bool parameter reads back as a bool or as 1 and 0', () async {
        final yes = await driver.query(echo, parameters: {'value': true});
        final no = await driver.query(echo, parameters: {'value': false});
        expect(yes.rows.single['value'], anyOf(isTrue, 1));
        expect(no.rows.single['value'], anyOf(isFalse, 0));
      });

      test('an unsupported parameter raises QueryExecutionException', () async {
        await expectLater(
          driver.query(echo, parameters: {'value': Object()}),
          throwsA(isA<QueryExecutionException>()
              .having((error) => error.sql, 'sql', echo)
              .having((error) => error.cause, 'cause', isNotNull)),
        );
      });
    });
  }
}
