import 'package:ratel_orm/ratel_orm.dart';
import 'package:ratel_orm/runtime.dart';
import 'package:ratel_orm/src/repository/entity_statements.dart';
import 'package:ratel_orm/src/runtime/entity_mapping.dart';
import 'package:test/test.dart';

import '../support/fixtures/definitions/gadget_definition.dart';
import '../support/fixtures/definitions/user_account_definition.dart';
import '../support/fixtures/entities/gadget.dart';
import '../support/fixtures/entities/gadget_kind.dart';
import '../support/legacy_sqlite_dialect.dart';

void main() {
  const dialect = PostgresDialect();
  const legacy = LegacySqliteDialect();
  final users = EntityMapping.of(UserAccountDefinition.value);
  final gadgets = EntityMapping.of(GadgetDefinition.value);
  final counters = EntityMapping.of(EntityDefinition<Gadget>(
    name: 'Gadget',
    table: 'counters',
    columns: const [ColumnDefinition(field: 'id', isId: true)],
    fromRow: GadgetDefinition.value.fromRow,
    toRow: (gadget) => {'id': gadget.id},
  ));
  final createdAt = DateTime.utc(2024, 5, 6);
  const userColumns = '"user_id", "email_address", "last_login_at"';
  const gadgetColumns = '"id", "display_name", "kind", "active", "price", '
      '"created_at", "note", "payload"';

  Map<String, Object?> user({Object? lastLoginAt}) => {
        'user_id': 7,
        'email_address': 'ada@example.com',
        'last_login_at': lastLoginAt,
      };

  Map<String, Object?> gadget({int? id}) => gadgets.columnValuesOf(Gadget(
        id: id,
        name: 'lamp',
        kind: GadgetKind.tool,
        active: true,
        price: 9.5,
        createdAt: createdAt,
        selected: true,
      ));

  group('select', () {
    test('lists every column explicitly', () {
      final built = EntityStatements.selectAll(dialect, users);
      expect(built.sql, 'SELECT $userColumns FROM "user_account"');
      expect(built.parameters, isEmpty);
    });

    test('matches the id column by @id', () {
      final built = EntityStatements.selectById(dialect, gadgets, 3);
      expect(
        built.sql,
        'SELECT $gadgetColumns FROM "gadgets" WHERE "id" = @id',
      );
      expect(built.parameters, {'id': 3});
    });
  });

  group('insert', () {
    test('inserts a set id and returns every column', () {
      final built = EntityStatements.insert(dialect, users, user());
      expect(
        built.sql,
        'INSERT INTO "user_account" ($userColumns) VALUES (@c0, @c1, @c2) '
        'RETURNING $userColumns',
      );
      expect(built.parameters, {
        'c0': 7,
        'c1': 'ada@example.com',
        'c2': null,
      });
    });

    test('omits a null id so the database generates it', () {
      final built = EntityStatements.insert(dialect, gadgets, gadget());
      expect(
        built.sql,
        'INSERT INTO "gadgets" ("display_name", "kind", "active", "price", '
        '"created_at", "note", "payload") '
        'VALUES (@c0, @c1, @c2, @c3, @c4, @c5, @c6) '
        'RETURNING $gadgetColumns',
      );
      expect(built.parameters, {
        'c0': 'lamp',
        'c1': 'tool',
        'c2': true,
        'c3': 9.5,
        'c4': createdAt,
        'c5': null,
        'c6': null,
      });
    });

    test('keeps a set id of an entity whose id may be generated', () {
      final built = EntityStatements.insert(dialect, gadgets, gadget(id: 4));
      expect(built.sql, startsWith('INSERT INTO "gadgets" ($gadgetColumns) '));
      expect(built.parameters['c0'], 4);
      expect(built.parameters, hasLength(8));
    });

    test('inserts default values when only a null id exists', () {
      final built = EntityStatements.insert(dialect, counters, {'id': null});
      expect(
        built.sql,
        'INSERT INTO "counters" DEFAULT VALUES RETURNING "id"',
      );
      expect(built.parameters, isEmpty);
    });

    test('leaves RETURNING out when the dialect lacks it', () {
      final built = EntityStatements.insert(legacy, users, user());
      expect(
        built.sql,
        'INSERT INTO "user_account" ($userColumns) VALUES (@c0, @c1, @c2)',
      );
    });
  });

  group('update', () {
    test('sets every other column and matches the id', () {
      final lastLoginAt = DateTime.utc(2024, 1, 2);
      final built = EntityStatements.update(
        dialect,
        users,
        user(lastLoginAt: lastLoginAt),
      );
      expect(
        built.sql,
        'UPDATE "user_account" SET "email_address" = @c0, '
        '"last_login_at" = @c1 WHERE "user_id" = @id RETURNING $userColumns',
      );
      expect(built.parameters, {
        'c0': 'ada@example.com',
        'c1': lastLoginAt,
        'id': 7,
      });
    });

    test('refuses an entity with no column besides its id', () {
      expect(
        () => EntityStatements.update(dialect, counters, {'id': 2}),
        throwsA(isA<ArgumentError>().having(
          (error) => error.message,
          'message',
          allOf(contains('Gadget'), contains('nothing to set')),
        )),
      );
    });

    test('leaves RETURNING out when the dialect lacks it', () {
      final built = EntityStatements.update(legacy, users, user());
      expect(
        built.sql,
        'UPDATE "user_account" SET "email_address" = @c0, '
        '"last_login_at" = @c1 WHERE "user_id" = @id',
      );
    });
  });

  test('deletes by id', () {
    final built = EntityStatements.deleteById(dialect, users, 7);
    expect(built.sql, 'DELETE FROM "user_account" WHERE "user_id" = @id');
    expect(built.parameters, {'id': 7});
  });

  test('escapes a double quote inside a table or column name', () {
    final quoted = EntityMapping.of(EntityDefinition<Gadget>(
      name: 'Gadget',
      table: 'we"ird',
      columns: const [
        ColumnDefinition(field: 'id', isId: true),
        ColumnDefinition(field: 'name', name: 'na"me'),
      ],
      fromRow: GadgetDefinition.value.fromRow,
      toRow: (gadget) => {'id': gadget.id, 'name': gadget.name},
    ));
    expect(
      EntityStatements.insert(dialect, quoted, {'id': null, 'na"me': 'x'}).sql,
      'INSERT INTO "we""ird" ("na""me") VALUES (@c0) RETURNING "id", "na""me"',
    );
  });
}
