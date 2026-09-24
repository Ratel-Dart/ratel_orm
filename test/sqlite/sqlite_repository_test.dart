import 'dart:typed_data';

import 'package:ratel_orm/ratel_orm.dart';
import 'package:ratel_orm/sqlite.dart';
import 'package:test/test.dart';

import '../support/fixtures/entities/counter.dart';
import '../support/fixtures/entities/gadget.dart';
import '../support/fixtures/entities/gadget_kind.dart';
import '../support/fixtures/entities/user_account.dart';
import '../support/fixtures/repositories/counter_repository.dart';
import '../support/fixtures/repositories/gadget_repository.dart';
import '../support/fixtures/repositories/user_account_repository.dart';
import '../support/legacy_sqlite_driver.dart';
import '../support/sqlite_test_library.dart';
import '../support/test_entities.dart';

void main() {
  setUpAll(SqliteTestLibrary.useSystemLibrary);
  TestEntities.install();

  const gadgetsTable = 'CREATE TABLE gadgets ('
      'id INTEGER PRIMARY KEY, '
      'display_name TEXT NOT NULL, '
      'kind TEXT NOT NULL, '
      'active INTEGER NOT NULL, '
      'price REAL NOT NULL, '
      'created_at TEXT NOT NULL, '
      'note TEXT, '
      'payload BLOB)';
  const accountsTable = 'CREATE TABLE user_account ('
      'user_id INTEGER PRIMARY KEY, '
      'email_address TEXT NOT NULL, '
      'last_login_at TEXT)';
  final createdAt = DateTime.utc(2024, 5, 6, 7, 8, 9, 10);
  final drivers = <String, SqliteDriver Function()>{
    'SQLite': SqliteDriver.memory,
    'SQLite without RETURNING': LegacySqliteDriver.new,
  };

  Gadget lamp() => Gadget(
        name: 'lamp',
        kind: GadgetKind.toy,
        active: true,
        price: 9.5,
        createdAt: createdAt.toLocal(),
        note: 'fragile',
        payload: Uint8List.fromList([1, 2, 3]),
        selected: true,
      );

  Gadget fan({int? id}) => Gadget(
        id: id,
        name: 'fan',
        kind: GadgetKind.tool,
        active: false,
        price: 12.25,
        createdAt: DateTime.utc(2025, 1, 2),
      );

  for (final MapEntry(key: label, value: create) in drivers.entries) {
    group('RatelRepository on $label', () {
      late SqliteDriver driver;
      late GadgetRepository gadgets;

      setUp(() async {
        driver = create();
        await driver.open();
        await driver.query(gadgetsTable);
        await driver.query(accountsTable);
        gadgets = GadgetRepository(driver);
      });

      tearDown(() => driver.close());

      test('insert generates the id and maps every value back', () async {
        final stored = await gadgets.insert(lamp());
        expect(stored.id, 1);
        expect(stored.name, 'lamp');
        expect(stored.kind, GadgetKind.toy);
        expect(stored.active, isTrue);
        expect(stored.price, 9.5);
        expect(stored.createdAt, createdAt);
        expect(stored.note, 'fragile');
        expect(stored.payload, [1, 2, 3]);
        expect(stored.selected, isFalse);
        expect((await gadgets.insert(lamp())).id, 2);
      });

      test('stores values the way SQLite keeps them', () async {
        await gadgets.insert(lamp());
        final raw = await driver.query(
          'SELECT display_name, kind, active, price, created_at, '
          'typeof(created_at) AS created_type FROM gadgets',
        );
        expect(raw.rows.single, {
          'display_name': 'lamp',
          'kind': 'toy',
          'active': 1,
          'price': 9.5,
          'created_at': '2024-05-06T07:08:09.010000Z',
          'created_type': 'text',
        });
      });

      test('nullable columns round-trip as null', () async {
        final stored = await gadgets.insert(fan());
        expect(stored.note, isNull);
        expect(stored.payload, isNull);
        expect(stored.active, isFalse);

        final found = await gadgets.findById(stored.id!);
        expect(found?.note, isNull);
        expect(found?.payload, isNull);
      });

      test('findById and findAll read what was stored', () async {
        final first = await gadgets.insert(lamp());
        final second = await gadgets.insert(fan());

        final found = await gadgets.findById(second.id!);
        expect(found?.name, 'fan');
        expect(found?.kind, GadgetKind.tool);
        expect(found?.price, 12.25);
        expect(found?.createdAt, DateTime.utc(2025, 1, 2));
        expect(await gadgets.findById(99), isNull);

        final all = await gadgets.findAll();
        expect([for (final gadget in all) gadget.id], [first.id, second.id]);
      });

      test('update writes every column and maps the stored row', () async {
        final stored = await gadgets.insert(lamp());
        final updated = await gadgets.update(fan(id: stored.id));
        expect(updated?.id, stored.id);
        expect(updated?.name, 'fan');
        expect(updated?.kind, GadgetKind.tool);
        expect(updated?.active, isFalse);
        expect(updated?.note, isNull);
        expect(updated?.payload, isNull);

        final found = await gadgets.findById(stored.id!);
        expect(found?.name, 'fan');
        expect(found?.price, 12.25);
        expect(found?.createdAt, DateTime.utc(2025, 1, 2));
      });

      test('update of a missing row yields null and writes nothing', () async {
        expect(await gadgets.update(fan(id: 42)), isNull);
        expect(await gadgets.findAll(), isEmpty);
      });

      test('deleteById reports whether a row was removed', () async {
        final stored = await gadgets.insert(lamp());
        expect(await gadgets.deleteById(stored.id!), isTrue);
        expect(await gadgets.deleteById(stored.id!), isFalse);
        expect(await gadgets.findById(stored.id!), isNull);
      });

      test('a set id is always inserted, under default names', () async {
        final accounts = UserAccountRepository(driver);
        final stored = await accounts.insert(UserAccount(
          userID: 40,
          emailAddress: 'ada@example.com',
          lastLoginAt: createdAt,
        ));
        expect(stored.userID, 40);
        expect(stored.lastLoginAt, createdAt);

        final raw = await driver.query(
          'SELECT user_id, email_address, last_login_at FROM user_account',
        );
        expect(raw.rows.single, {
          'user_id': 40,
          'email_address': 'ada@example.com',
          'last_login_at': '2024-05-06T07:08:09.010000Z',
        });
      });

      test('maps columns declared in another letter case', () async {
        await driver.query('DROP TABLE gadgets');
        await driver.query(gadgetsTable.toUpperCase());

        final stored = await gadgets.insert(lamp());
        expect(stored.id, 1);
        expect(stored.name, 'lamp');
        expect(stored.note, 'fragile');
        expect(stored.payload, [1, 2, 3]);

        final found = await gadgets.findById(1);
        expect(found?.note, 'fragile');
        expect(found?.createdAt, createdAt);

        final updated = await gadgets.update(fan(id: 1));
        expect(updated?.name, 'fan');
        expect(updated?.note, isNull);

        expect([for (final g in await gadgets.findAll()) g.name], ['fan']);
        expect(
          [
            for (final g in await gadgets.execute('SELECT * FROM gadgets'))
              g.name,
          ],
          ['fan'],
        );
        expect(
          [for (final g in await gadgets.find(Query.from('gadgets'))) g.name],
          ['fan'],
        );
      });

      test('an entity with only an id inserts and reads itself back', () async {
        await driver.query('CREATE TABLE counters (id INTEGER PRIMARY KEY)');
        final counters = CounterRepository(driver);

        final stored = await counters.insert(const Counter());
        expect(stored.id, 1);
        expect((await counters.update(stored))?.id, 1);
        expect(await counters.update(const Counter(id: 9)), isNull);
        expect(await counters.deleteById(1), isTrue);
      });

      test('find and execute map rows and yield an empty list for none',
          () async {
        await gadgets.insert(lamp());
        await gadgets.insert(fan());

        final toys =
            await gadgets.find(Query.from('gadgets').where('kind', '=', 'toy'));
        expect([for (final gadget in toys) gadget.name], ['lamp']);

        final pricey = await gadgets.execute(
          'SELECT * FROM gadgets WHERE price > @min',
          parameters: {'min': 100},
        );
        expect(pricey, isEmpty);
      });

      test('writes made in a failed transaction roll back', () async {
        await expectLater(
          driver.transaction((session) async {
            await gadgets.insert(lamp());
            throw StateError('undo');
          }),
          throwsStateError,
        );
        expect(await gadgets.findAll(), isEmpty);
      });
    });
  }
}
