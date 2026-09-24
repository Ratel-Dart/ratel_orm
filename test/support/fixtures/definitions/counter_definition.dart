import 'package:ratel_orm/runtime.dart';

import '../entities/counter.dart';

abstract final class CounterDefinition {
  static const value = EntityDefinition<Counter>(
    name: 'Counter',
    table: 'counters',
    columns: [
      ColumnDefinition(field: 'id', isId: true),
    ],
    fromRow: _fromRow,
    toRow: _toRow,
  );

  static Counter _fromRow(EntityRow row) =>
      Counter(id: row.integerOrNull('id'));

  static Map<String, Object?> _toRow(Counter counter) => {'id': counter.id};
}
