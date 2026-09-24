import 'package:ratel_orm/runtime.dart';

import '../entities/person.dart';

abstract final class PersonDefinition {
  static const value = EntityDefinition<Person>(
    name: 'Person',
    columns: [
      ColumnDefinition(field: 'id', isId: true),
      ColumnDefinition(field: 'name'),
      ColumnDefinition(field: 'age'),
    ],
    fromRow: _fromRow,
    toRow: _toRow,
  );

  static Person _fromRow(EntityRow row) => Person(
        id: row.integer('id'),
        name: row.text('name'),
        age: row.integer('age'),
      );

  static Map<String, Object?> _toRow(Person person) => {
        'id': person.id,
        'name': person.name,
        'age': person.age,
      };
}
