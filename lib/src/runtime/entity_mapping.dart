import '../exceptions/mapping_exception.dart';
import 'entity_definition.dart';
import 'sql_names.dart';

final class EntityMapping {
  EntityMapping._({
    required this.definition,
    required this.table,
    required this.idField,
    required Map<String, String> columnsByField,
  })  : _columnsByField = columnsByField,
        columns = List.unmodifiable(columnsByField.values);

  static final Expando<EntityMapping> _resolved = Expando('EntityMapping');

  static EntityMapping of(EntityDefinition<Object> definition) =>
      _resolved[definition] ??= _resolve(definition);

  final EntityDefinition<Object> definition;
  final String table;
  final String idField;
  final List<String> columns;
  final Map<String, String> _columnsByField;

  String get entity => definition.name;

  Type get type => definition.type;

  String get idColumn => _columnsByField[idField]!;

  Iterable<String> get fields => _columnsByField.keys;

  String columnOf(String field) =>
      _columnsByField[field] ??
      (throw MappingException(
        'The entity $entity has no column for the field "$field".',
      ));

  Map<String, Object?> columnValuesOf(Object instance) {
    final values = definition.rowOf(instance);
    for (final field in values.keys) {
      if (!_columnsByField.containsKey(field)) {
        throw MappingException(
          '$entity.toRow returned "$field", which is not a column '
          'field of $entity.',
        );
      }
    }
    return {
      for (final MapEntry(key: field, value: column) in _columnsByField.entries)
        column: values.containsKey(field)
            ? values[field]
            : throw MappingException(
                '$entity.toRow did not return the column field '
                '"$field".',
              ),
    };
  }

  static EntityMapping _resolve(EntityDefinition<Object> definition) {
    final entity = definition.name;
    if (entity.isEmpty) {
      throw StateError(
        'An entity definition for ${definition.type} has an empty name.',
      );
    }
    final table = definition.table ?? SqlNames.of(entity);
    if (table.isEmpty) {
      throw StateError('The entity $entity has an empty table name.');
    }
    final columnsByField = <String, String>{};
    final fieldsByColumn = <String, String>{};
    final ids = <String>[];
    for (final column in definition.columns) {
      final field = column.field;
      if (field.isEmpty) {
        throw StateError(
          'The entity $entity has a column with an empty field name.',
        );
      }
      final name = column.name ?? SqlNames.of(field);
      if (name.isEmpty) {
        throw StateError(
          'The entity $entity maps the field "$field" to an empty column name.',
        );
      }
      if (columnsByField.containsKey(field)) {
        throw StateError('The entity $entity declares the field "$field" '
            'twice.');
      }
      final clash = fieldsByColumn[name];
      if (clash != null) {
        throw StateError('The entity $entity maps both "$clash" and "$field" '
            'to the column "$name".');
      }
      columnsByField[field] = name;
      fieldsByColumn[name] = field;
      if (column.isId) ids.add(field);
    }
    if (ids.length != 1) {
      final found = ids.isEmpty ? 'none' : ids.join(', ');
      throw StateError(
        'The entity $entity needs exactly one @Id() column, found $found.',
      );
    }
    return EntityMapping._(
      definition: definition,
      table: table,
      idField: ids.single,
      columnsByField: Map.unmodifiable(columnsByField),
    );
  }
}
