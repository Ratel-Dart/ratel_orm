import 'package:ratel_orm/runtime.dart';

import '../entities/labeled_widget.dart';

abstract final class LabeledWidgetDefinition {
  static const value = EntityDefinition<LabeledWidget>(
    name: 'LabeledWidget',
    table: 'ratel_repo_widgets',
    columns: [
      ColumnDefinition(field: 'id', isId: true),
      ColumnDefinition(field: 'label'),
    ],
    fromRow: _fromRow,
    toRow: _toRow,
  );

  static LabeledWidget _fromRow(EntityRow row) =>
      LabeledWidget(id: row.integer('id'), label: row.text('label'));

  static Map<String, Object?> _toRow(LabeledWidget widget) => {
        'id': widget.id,
        'label': widget.label,
      };
}
