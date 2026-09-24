import 'package:ratel_orm/runtime.dart';
import 'package:ratel_orm/src/runtime/entity_catalog.dart';
import 'package:test/test.dart';

import '../support/fixtures/definitions/gadget_definition.dart';
import '../support/fixtures/entities/gadget.dart';
import '../support/fixtures/entities/user_account.dart';
import '../support/test_entities.dart';

void main() {
  EntityDefinition<Gadget> gadget(
    List<ColumnDefinition> columns, {
    String name = 'Gadget',
    String? table,
  }) =>
      EntityDefinition<Gadget>(
        name: name,
        table: table,
        columns: columns,
        fromRow: GadgetDefinition.value.fromRow,
        toRow: GadgetDefinition.value.toRow,
      );

  void expectRefused(
      List<EntityDefinition<Object>> entities, List<String> fragments) {
    expect(
      () => EntityCatalog.of(EntityManifest(entities: entities)),
      throwsA(isA<StateError>().having(
        (error) => error.message,
        'message',
        allOf([for (final fragment in fragments) contains(fragment)]),
      )),
    );
  }

  test('maps every entity of the manifest by its type', () {
    final catalog = EntityCatalog.of(TestEntities.manifest);
    expect(catalog.manifest, same(TestEntities.manifest));
    expect(catalog.lookup(Gadget)?.table, 'gadgets');
    expect(catalog.lookup(UserAccount)?.table, 'user_account');
    expect(catalog.lookup(String), isNull);
    expect(
      [for (final mapping in catalog.entities) mapping.entity],
      [
        'Gadget',
        'UserAccount',
        'Widget',
        'Note',
        'Person',
        'LabeledWidget',
        'Bookmark',
        'Counter',
      ],
    );
  });

  test('builds the catalog of a manifest once', () {
    expect(
      EntityCatalog.of(TestEntities.manifest),
      same(EntityCatalog.of(TestEntities.manifest)),
    );
  });

  test('accepts an empty manifest', () {
    expect(EntityCatalog.of(const EntityManifest()).entities, isEmpty);
  });

  test('refuses an entity type listed twice', () {
    expectRefused(
      [
        GadgetDefinition.value,
        gadget(GadgetDefinition.value.columns, name: 'OtherGadget'),
      ],
      ['Gadget', 'OtherGadget', 'twice'],
    );
  });

  test('refuses an entity without an id', () {
    expectRefused(
      [
        gadget(const [ColumnDefinition(field: 'name')]),
      ],
      ['Gadget', '@Id()', 'none'],
    );
  });

  test('refuses an entity with two ids', () {
    expectRefused(
      [
        gadget(const [
          ColumnDefinition(field: 'id', isId: true),
          ColumnDefinition(field: 'name', isId: true),
        ]),
      ],
      ['Gadget', '@Id()', 'id, name'],
    );
  });

  test('refuses two fields mapped to one column', () {
    expectRefused(
      [
        gadget(const [
          ColumnDefinition(field: 'id', isId: true),
          ColumnDefinition(field: 'createdAt'),
          ColumnDefinition(field: 'created', name: 'created_at'),
        ]),
      ],
      ['Gadget', '"createdAt"', '"created"', '"created_at"'],
    );
  });

  test('refuses a field declared twice', () {
    expectRefused(
      [
        gadget(const [
          ColumnDefinition(field: 'id', isId: true),
          ColumnDefinition(field: 'name'),
          ColumnDefinition(field: 'name', name: 'label'),
        ]),
      ],
      ['Gadget', '"name"', 'twice'],
    );
  });

  test('refuses an empty column name', () {
    expectRefused(
      [
        gadget(const [
          ColumnDefinition(field: 'id', isId: true),
          ColumnDefinition(field: 'name', name: ''),
        ]),
      ],
      ['Gadget', '"name"', 'empty column name'],
    );
  });

  test('refuses an empty field name, even with a column name', () {
    final refused = throwsA(isA<StateError>().having(
      (error) => error.message,
      'message',
      'The entity Gadget has a column with an empty field name.',
    ));
    for (final column in const [
      ColumnDefinition(field: ''),
      ColumnDefinition(field: '', name: 'email_address'),
    ]) {
      expect(
        () => EntityCatalog.of(EntityManifest(entities: [
          gadget([const ColumnDefinition(field: 'id', isId: true), column]),
        ])),
        refused,
      );
    }
  });

  test('refuses an empty table name', () {
    expect(
      () => EntityCatalog.of(EntityManifest(entities: [
        gadget(const [ColumnDefinition(field: 'id', isId: true)], table: ''),
      ])),
      throwsA(isA<StateError>().having(
        (error) => error.message,
        'message',
        'The entity Gadget has an empty table name.',
      )),
    );
  });

  test('refuses an empty entity name before deriving a table from it', () {
    expect(
      () => EntityCatalog.of(EntityManifest(entities: [
        gadget(const [ColumnDefinition(field: 'id', isId: true)], name: ''),
      ])),
      throwsA(isA<StateError>().having(
        (error) => error.message,
        'message',
        'An entity definition for Gadget has an empty name.',
      )),
    );
  });
}
