import 'column_definition.dart';
import 'entity_row.dart';

final class EntityDefinition<T extends Object> {
  const EntityDefinition({
    required this.name,
    this.table,
    required this.columns,
    required this.fromRow,
    required this.toRow,
  });

  final String name;
  final String? table;
  final List<ColumnDefinition> columns;
  final T Function(EntityRow row) fromRow;
  final Map<String, Object?> Function(T entity) toRow;

  Type get type => T;

  Map<String, Object?> rowOf(Object entity) => toRow(entity as T);
}
