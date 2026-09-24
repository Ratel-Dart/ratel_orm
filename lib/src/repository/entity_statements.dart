import '../dialect/sql_dialect.dart';
import '../query/built_query.dart';
import '../runtime/entity_mapping.dart';

abstract final class EntityStatements {
  static BuiltQuery selectAll(SqlDialect dialect, EntityMapping entity) =>
      BuiltQuery(_select(dialect, entity), const {});

  static BuiltQuery selectById(
    SqlDialect dialect,
    EntityMapping entity,
    Object id,
  ) =>
      BuiltQuery(
        '${_select(dialect, entity)} WHERE ${_idMatch(dialect, entity)}',
        {'id': id},
      );

  static BuiltQuery insert(
    SqlDialect dialect,
    EntityMapping entity,
    Map<String, Object?> values,
  ) {
    final columns = [
      for (final column in entity.columns)
        if (column != entity.idColumn || values[column] != null) column,
    ];
    final parameters = <String, Object?>{
      for (var i = 0; i < columns.length; i++) 'c$i': values[columns[i]],
    };
    final target = columns.isEmpty
        ? 'DEFAULT VALUES'
        : '(${columns.map(dialect.quoteIdentifier).join(', ')}) '
            'VALUES (${parameters.keys.map((name) => '@$name').join(', ')})';
    return BuiltQuery(
      'INSERT INTO ${_table(dialect, entity)} $target'
      '${_returning(dialect, entity)}',
      parameters,
    );
  }

  static BuiltQuery update(
    SqlDialect dialect,
    EntityMapping entity,
    Map<String, Object?> values,
  ) {
    final columns = [
      for (final column in entity.columns)
        if (column != entity.idColumn) column,
    ];
    if (columns.isEmpty) {
      throw ArgumentError(
        'The entity ${entity.entity} has no column besides its id, so an '
            'UPDATE has nothing to set.',
        'entity',
      );
    }
    final parameters = <String, Object?>{
      for (var i = 0; i < columns.length; i++) 'c$i': values[columns[i]],
    };
    final assignments = [
      for (var i = 0; i < columns.length; i++)
        '${dialect.quoteIdentifier(columns[i])} = @c$i',
    ].join(', ');
    return BuiltQuery(
      'UPDATE ${_table(dialect, entity)} SET $assignments '
      'WHERE ${_idMatch(dialect, entity)}${_returning(dialect, entity)}',
      {...parameters, 'id': values[entity.idColumn]},
    );
  }

  static BuiltQuery deleteById(
    SqlDialect dialect,
    EntityMapping entity,
    Object id,
  ) =>
      BuiltQuery(
        'DELETE FROM ${_table(dialect, entity)} '
        'WHERE ${_idMatch(dialect, entity)}',
        {'id': id},
      );

  static String _select(SqlDialect dialect, EntityMapping entity) =>
      'SELECT ${_columnList(dialect, entity)} FROM ${_table(dialect, entity)}';

  static String _returning(SqlDialect dialect, EntityMapping entity) =>
      dialect.supportsReturning
          ? ' RETURNING ${_columnList(dialect, entity)}'
          : '';

  static String _columnList(SqlDialect dialect, EntityMapping entity) =>
      entity.columns.map(dialect.quoteIdentifier).join(', ');

  static String _table(SqlDialect dialect, EntityMapping entity) =>
      dialect.quoteIdentifier(entity.table);

  static String _idMatch(SqlDialect dialect, EntityMapping entity) =>
      '${dialect.quoteIdentifier(entity.idColumn)} = @id';
}
