import 'package:ratel_orm/runtime.dart';

import '../entities/note.dart';

abstract final class NoteDefinition {
  static const value = EntityDefinition<Note>(
    name: 'Note',
    table: 'notes',
    columns: [
      ColumnDefinition(field: 'id', isId: true),
      ColumnDefinition(field: 'body'),
    ],
    fromRow: _fromRow,
    toRow: _toRow,
  );

  static Note _fromRow(EntityRow row) =>
      Note(id: row.integer('id'), body: row.text('body'));

  static Map<String, Object?> _toRow(Note note) => {
        'id': note.id,
        'body': note.body,
      };
}
