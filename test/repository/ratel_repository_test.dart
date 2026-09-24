import 'package:ratel_orm/ratel_orm.dart';
import 'package:ratel_orm/testing.dart';
import 'package:test/test.dart';

import '../support/fixtures/entities/counter.dart';
import '../support/fixtures/entities/gadget.dart';
import '../support/fixtures/entities/gadget_kind.dart';
import '../support/fixtures/entities/widget.dart';
import '../support/fixtures/repositories/bookmark_repository.dart';
import '../support/fixtures/repositories/counter_repository.dart';
import '../support/fixtures/repositories/gadget_repository.dart';
import '../support/fixtures/repositories/not_an_entity_repository.dart';
import '../support/fixtures/repositories/user_account_repository.dart';
import '../support/fixtures/repositories/widget_repository.dart';
import '../support/legacy_fake_driver.dart';
import '../support/test_entities.dart';

void main() {
  TestEntities.install();

  const widgetColumns = '"id", "name"';
  const gadgetColumns = '"id", "display_name", "kind", "active", "price", '
      '"created_at", "note", "payload"';
  final createdAt = DateTime.utc(2024, 5, 6, 7, 8, 9);

  late FakeDriver fake;
  late WidgetRepository widgets;

  Map<String, Object?> gadgetRow(int id) => {
        'id': id,
        'display_name': 'lamp',
        'kind': 'toy',
        'active': true,
        'price': 9.5,
        'created_at': createdAt,
        'note': null,
        'payload': null,
      };

  Gadget lamp({int? id}) => Gadget(
        id: id,
        name: 'lamp',
        kind: GadgetKind.toy,
        active: true,
        price: 9.5,
        createdAt: createdAt,
        selected: true,
      );

  setUp(() {
    fake = FakeDriver();
    widgets = WidgetRepository(fake);
  });

  group('resolution', () {
    test('resolves the table of its entity', () {
      expect(widgets.table, 'widgets');
      expect(GadgetRepository(fake).table, 'gadgets');
      expect(UserAccountRepository(fake).table, 'user_account');
    });

    test('refuses a type that is not an entity as soon as it is built', () {
      expect(
        () => NotAnEntityRepository(fake),
        throwsA(isA<StateError>().having(
          (error) => error.message,
          'message',
          'NotAnEntity is not an @Entity: annotate it with @Entity() and '
              'give it an @Id() field.',
        )),
      );
      expect(fake.lastSql, isNull);
    });
  });

  group('findAll', () {
    test('selects every column and maps each row', () async {
      fake.enqueueRows([
        {'id': 1, 'name': 'a'},
        {'id': 2, 'name': 'b'},
      ]);
      final found = await widgets.findAll();
      expect(fake.lastSql, 'SELECT $widgetColumns FROM "widgets"');
      expect([for (final widget in found) widget.id], [1, 2]);
      expect([for (final widget in found) widget.name], ['a', 'b']);
    });

    test('yields an empty list when there are no rows', () async {
      expect(await widgets.findAll(), isEmpty);
    });
  });

  group('findById', () {
    test('matches the id and maps the row', () async {
      fake.enqueueRows([
        {'id': 5, 'name': 'e'},
      ]);
      final found = await widgets.findById(5);
      expect(
        fake.lastSql,
        'SELECT $widgetColumns FROM "widgets" WHERE "id" = @id',
      );
      expect(fake.lastParameters, {'id': 5});
      expect(found?.name, 'e');
    });

    test('yields null when no row matches', () async {
      expect(await widgets.findById(5), isNull);
    });
  });

  group('insert', () {
    test('inserts a set id and maps the returned row', () async {
      fake.enqueueRows([
        {'id': 1, 'name': 'stored'},
      ]);
      final stored = await widgets.insert(const Widget(id: 1, name: 'a'));
      expect(
        fake.lastSql,
        'INSERT INTO "widgets" ("id", "name") VALUES (@c0, @c1) '
        'RETURNING $widgetColumns',
      );
      expect(fake.lastParameters, {'c0': 1, 'c1': 'a'});
      expect(stored.name, 'stored');
    });

    test('omits a null id and maps the generated one back', () async {
      fake.enqueueRows([gadgetRow(12)]);
      final stored = await GadgetRepository(fake).insert(lamp());
      expect(
        fake.lastSql,
        'INSERT INTO "gadgets" ("display_name", "kind", "active", "price", '
        '"created_at", "note", "payload") '
        'VALUES (@c0, @c1, @c2, @c3, @c4, @c5, @c6) '
        'RETURNING $gadgetColumns',
      );
      expect(fake.lastParameters, {
        'c0': 'lamp',
        'c1': 'toy',
        'c2': true,
        'c3': 9.5,
        'c4': createdAt,
        'c5': null,
        'c6': null,
      });
      expect(stored.id, 12);
      expect(stored.kind, GadgetKind.toy);
      expect(stored.selected, isFalse);
    });

    test('fails when the database returns no row', () async {
      await expectLater(
        widgets.insert(const Widget(id: 1, name: 'a')),
        throwsA(isA<QueryExecutionException>()
            .having((error) => error.sql, 'sql', startsWith('INSERT INTO'))
            .having((error) => error.message, 'message', contains('Widget'))),
      );
    });
  });

  group('update', () {
    test('sets the other columns by id and maps the returned row', () async {
      fake.enqueueRows([
        {'id': 1, 'name': 'b'},
      ]);
      final stored = await widgets.update(const Widget(id: 1, name: 'b'));
      expect(
        fake.lastSql,
        'UPDATE "widgets" SET "name" = @c0 WHERE "id" = @id '
        'RETURNING $widgetColumns',
      );
      expect(fake.lastParameters, {'c0': 'b', 'id': 1});
      expect(stored?.name, 'b');
    });

    test('yields null when no row matches', () async {
      expect(await widgets.update(const Widget(id: 1, name: 'b')), isNull);
    });

    test('reads an entity with only an id back instead of updating it',
        () async {
      final counters = CounterRepository(fake);
      fake.enqueueRows([
        {'id': 2},
      ]);
      final stored = await counters.update(const Counter(id: 2));
      expect(fake.lastSql, 'SELECT "id" FROM "counters" WHERE "id" = @id');
      expect(fake.lastParameters, {'id': 2});
      expect(stored?.id, 2);

      expect(await counters.update(const Counter(id: 3)), isNull);
      expect(fake.lastSql, startsWith('SELECT'));
    });

    test('refuses an entity without an id before touching the driver',
        () async {
      await expectLater(
        GadgetRepository(fake).update(lamp()),
        throwsA(isA<ArgumentError>().having(
          (error) => error.message,
          'message',
          allOf(contains('Gadget'), contains('"id"')),
        )),
      );
      expect(fake.lastSql, isNull);
    });
  });

  group('deleteById', () {
    test('deletes by id and reports a removed row', () async {
      fake.enqueue(const QueryResult(affectedRows: 1));
      expect(await widgets.deleteById(3), isTrue);
      expect(fake.lastSql, 'DELETE FROM "widgets" WHERE "id" = @id');
      expect(fake.lastParameters, {'id': 3});
    });

    test('reports false when no row matched', () async {
      expect(await widgets.deleteById(3), isFalse);
    });
  });

  group('without RETURNING', () {
    late LegacyFakeDriver legacy;

    setUp(() => legacy = LegacyFakeDriver());

    test('insert reads a generated id back through lastInsertId', () async {
      legacy
        ..enqueue(const QueryResult(affectedRows: 1, lastInsertId: 9))
        ..enqueueRows([gadgetRow(9)]);
      final stored = await GadgetRepository(legacy).insert(lamp());
      expect(legacy.statements, [
        'INSERT INTO "gadgets" ("display_name", "kind", "active", "price", '
            '"created_at", "note", "payload") '
            'VALUES (@c0, @c1, @c2, @c3, @c4, @c5, @c6)',
        'SELECT $gadgetColumns FROM "gadgets" WHERE "id" = @id',
      ]);
      expect(legacy.lastParameters, {'id': 9});
      expect(stored.id, 9);
    });

    test('insert reads a set id back by that id', () async {
      legacy
        ..enqueue(const QueryResult(affectedRows: 1, lastInsertId: 77))
        ..enqueueRows([
          {'id': 4, 'name': 'd'},
        ]);
      final stored =
          await WidgetRepository(legacy).insert(const Widget(id: 4, name: 'd'));
      expect(legacy.lastParameters, {'id': 4});
      expect(stored.id, 4);
    });

    test('insert fails when the database reports no id', () async {
      await expectLater(
        GadgetRepository(legacy).insert(lamp()),
        throwsA(isA<QueryExecutionException>()
            .having((error) => error.message, 'message', contains('no id'))),
      );
      expect(legacy.statements, hasLength(1));
    });

    test('update reads the row back after a match', () async {
      legacy
        ..enqueue(const QueryResult(affectedRows: 1))
        ..enqueueRows([
          {'id': 1, 'name': 'b'},
        ]);
      final stored =
          await WidgetRepository(legacy).update(const Widget(id: 1, name: 'b'));
      expect(legacy.statements, [
        'UPDATE "widgets" SET "name" = @c0 WHERE "id" = @id',
        'SELECT $widgetColumns FROM "widgets" WHERE "id" = @id',
      ]);
      expect(stored?.name, 'b');
    });

    test('update of an entity with only an id only reads it', () async {
      legacy.enqueueRows([
        {'id': 6},
      ]);
      final stored =
          await CounterRepository(legacy).update(const Counter(id: 6));
      expect(legacy.statements, [
        'SELECT "id" FROM "counters" WHERE "id" = @id',
      ]);
      expect(stored?.id, 6);
    });

    test('update yields null without reading when nothing matched', () async {
      final stored =
          await WidgetRepository(legacy).update(const Widget(id: 1, name: 'b'));
      expect(stored, isNull);
      expect(legacy.statements, hasLength(1));
    });
  });

  group('execute and find', () {
    test('forwards parameters to the driver', () async {
      fake.enqueueRows([
        {'id': 5, 'name': 'b'},
      ]);
      final found = await widgets.named('b');
      expect(fake.lastSql, 'SELECT * FROM widgets WHERE name = @name');
      expect(fake.lastParameters, {'name': 'b'});
      expect(found.single.id, 5);
    });

    test('yields an empty list when there are no rows', () async {
      expect(await widgets.named('b'), isEmpty);
      expect(await widgets.find(Query.from('widgets')), isEmpty);
    });

    test('appends RETURNING * on request', () async {
      await widgets.execute(
        'DELETE FROM widgets WHERE id = @id',
        parameters: {'id': 1},
        returning: true,
      );
      expect(fake.lastSql, 'DELETE FROM widgets WHERE id = @id RETURNING *');
    });

    test('find runs a built query', () async {
      fake.enqueueRows([
        {'id': 2, 'name': 'b'},
      ]);
      final found =
          await widgets.find(Query.from('widgets').where('id', '=', 2));
      expect(fake.lastSql, 'SELECT * FROM "widgets" WHERE "id" = @p0');
      expect(fake.lastParameters, {'p0': 2});
      expect(found.single.name, 'b');
    });

    test('a driver error propagates untouched', () async {
      final error = QueryExecutionException('boom', sql: 'x');
      fake.errorToThrow = error;
      await expectLater(widgets.findAll(), throwsA(same(error)));
    });
  });

  group('mapping', () {
    test('a value EntityRow cannot convert raises MappingException', () async {
      fake.enqueueRows([
        {'id': 'not-an-int', 'name': 'a'},
      ]);
      await expectLater(
        widgets.findAll(),
        throwsA(isA<MappingException>().having(
          (error) => error.message,
          'message',
          allOf(contains('Widget.id'), contains('"id"'), contains('String')),
        )),
      );
    });

    test('a column declared in another letter case still maps', () async {
      fake.enqueueRows([
        {'ID': 1, 'Name': 'a'},
      ]);
      final found = await widgets.findById(1);
      expect(found?.id, 1);
      expect(found?.name, 'a');
    });

    test('a column missing from the row raises MappingException', () async {
      fake.enqueueRows([
        {'id': 1},
      ]);
      await expectLater(
        widgets.findById(1),
        throwsA(isA<MappingException>().having(
          (error) => error.message,
          'message',
          allOf(contains('Widget.name'), contains('"name"')),
        )),
      );
    });

    test('any other failure in fromRow is wrapped in MappingException',
        () async {
      fake.enqueueRows([
        {'id': 1, 'url': 'http://['},
      ]);
      await expectLater(
        BookmarkRepository(fake).findAll(),
        throwsA(isA<MappingException>()
            .having((error) => error.message, 'message', contains('Bookmark'))
            .having((error) => error.cause, 'cause', isA<FormatException>())),
      );
    });
  });
}
