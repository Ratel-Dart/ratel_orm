import 'package:ratel_orm/runtime.dart';

import '../entities/widget.dart';

abstract final class WidgetDefinition {
  static const value = EntityDefinition<Widget>(
    name: 'Widget',
    table: 'widgets',
    columns: [
      ColumnDefinition(field: 'id', isId: true),
      ColumnDefinition(field: 'name'),
    ],
    fromRow: _fromRow,
    toRow: _toRow,
  );

  static Widget _fromRow(EntityRow row) =>
      Widget(id: row.integer('id'), name: row.text('name'));

  static Map<String, Object?> _toRow(Widget widget) => {
        'id': widget.id,
        'name': widget.name,
      };
}
