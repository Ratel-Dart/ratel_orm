import 'package:ratel_orm/runtime.dart';

import '../entities/gadget.dart';
import '../entities/gadget_kind.dart';

abstract final class GadgetDefinition {
  static const value = EntityDefinition<Gadget>(
    name: 'Gadget',
    table: 'gadgets',
    columns: [
      ColumnDefinition(field: 'id', isId: true),
      ColumnDefinition(field: 'name', name: 'display_name'),
      ColumnDefinition(field: 'kind'),
      ColumnDefinition(field: 'active'),
      ColumnDefinition(field: 'price'),
      ColumnDefinition(field: 'createdAt'),
      ColumnDefinition(field: 'note'),
      ColumnDefinition(field: 'payload'),
    ],
    fromRow: _fromRow,
    toRow: _toRow,
  );

  static Gadget _fromRow(EntityRow row) => Gadget(
        id: row.integerOrNull('id'),
        name: row.text('name'),
        kind: row.enumeration('kind', GadgetKind.values),
        active: row.boolean('active'),
        price: row.real('price'),
        createdAt: row.dateTime('createdAt'),
        note: row.textOrNull('note'),
        payload: row.bytesOrNull('payload'),
      );

  static Map<String, Object?> _toRow(Gadget gadget) => {
        'id': gadget.id,
        'name': gadget.name,
        'kind': gadget.kind.name,
        'active': gadget.active,
        'price': gadget.price,
        'createdAt': gadget.createdAt,
        'note': gadget.note,
        'payload': gadget.payload,
      };
}
