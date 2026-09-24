import 'package:ratel_orm/ratel_orm.dart';
import 'package:ratel_orm/runtime.dart';
import 'package:ratel_orm/src/runtime/entity_mapping.dart';
import 'package:test/test.dart';

import '../support/fixtures/definitions/gadget_definition.dart';
import '../support/fixtures/definitions/user_account_definition.dart';
import '../support/fixtures/entities/gadget.dart';
import '../support/fixtures/entities/gadget_kind.dart';
import '../support/fixtures/entities/user_account.dart';

void main() {
  const gadgetColumns = [
    'id',
    'display_name',
    'kind',
    'active',
    'price',
    'created_at',
    'note',
    'payload',
  ];

  test('derives table and column names from the entity and its fields', () {
    final mapping = EntityMapping.of(UserAccountDefinition.value);
    expect(mapping.entity, 'UserAccount');
    expect(mapping.type, UserAccount);
    expect(mapping.table, 'user_account');
    expect(mapping.fields, ['userID', 'emailAddress', 'lastLoginAt']);
    expect(mapping.columns, ['user_id', 'email_address', 'last_login_at']);
    expect(mapping.idField, 'userID');
    expect(mapping.idColumn, 'user_id');
  });

  test('honours explicit table and column names', () {
    final mapping = EntityMapping.of(GadgetDefinition.value);
    expect(mapping.table, 'gadgets');
    expect(mapping.columnOf('name'), 'display_name');
    expect(mapping.columnOf('createdAt'), 'created_at');
    expect(mapping.columns, gadgetColumns);
  });

  test('resolves a definition once', () {
    expect(
      EntityMapping.of(GadgetDefinition.value),
      same(EntityMapping.of(GadgetDefinition.value)),
    );
  });

  test('refuses a field that is not a column', () {
    expect(
      () => EntityMapping.of(GadgetDefinition.value).columnOf('selected'),
      throwsA(isA<MappingException>().having(
        (error) => error.message,
        'message',
        allOf(contains('Gadget'), contains('"selected"')),
      )),
    );
  });

  test('turns an entity into column values in column order', () {
    final createdAt = DateTime.utc(2024, 5, 6);
    final values = EntityMapping.of(GadgetDefinition.value).columnValuesOf(
      Gadget(
        name: 'lamp',
        kind: GadgetKind.toy,
        active: false,
        price: 2.5,
        createdAt: createdAt,
        selected: true,
      ),
    );
    expect(values.keys, gadgetColumns);
    expect(values['id'], isNull);
    expect(values['display_name'], 'lamp');
    expect(values['kind'], 'toy');
    expect(values['active'], isFalse);
    expect(values['created_at'], createdAt);
  });

  test('refuses a toRow that leaves out a column field', () {
    final definition = EntityDefinition<UserAccount>(
      name: 'UserAccount',
      columns: UserAccountDefinition.value.columns,
      fromRow: UserAccountDefinition.value.fromRow,
      toRow: (account) => {'userID': account.userID},
    );
    expect(
      () => EntityMapping.of(definition).columnValuesOf(
        const UserAccount(userID: 1, emailAddress: 'a@example.com'),
      ),
      throwsA(isA<MappingException>().having(
        (error) => error.message,
        'message',
        allOf(contains('UserAccount'), contains('"emailAddress"')),
      )),
    );
  });

  test('refuses a toRow that returns a field that is not a column', () {
    final definition = EntityDefinition<UserAccount>(
      name: 'UserAccount',
      columns: UserAccountDefinition.value.columns,
      fromRow: UserAccountDefinition.value.fromRow,
      toRow: (account) => {
        'userID': account.userID,
        'emailAddress': account.emailAddress,
        'lastLoginAt': null,
        'password': 'secret',
      },
    );
    expect(
      () => EntityMapping.of(definition).columnValuesOf(
        const UserAccount(userID: 1, emailAddress: 'a@example.com'),
      ),
      throwsA(isA<MappingException>().having(
        (error) => error.message,
        'message',
        allOf(contains('UserAccount'), contains('"password"')),
      )),
    );
  });
}
