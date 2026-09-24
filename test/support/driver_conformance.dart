import 'package:ratel_orm/ratel_orm.dart';
import 'package:test/test.dart';

abstract final class DriverConformance {
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
