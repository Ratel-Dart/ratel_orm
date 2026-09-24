import 'package:ratel_orm/runtime.dart';

import '../entities/bookmark.dart';

abstract final class BookmarkDefinition {
  static const value = EntityDefinition<Bookmark>(
    name: 'Bookmark',
    table: 'bookmarks',
    columns: [
      ColumnDefinition(field: 'id', isId: true),
      ColumnDefinition(field: 'url'),
    ],
    fromRow: _fromRow,
    toRow: _toRow,
  );

  static Bookmark _fromRow(EntityRow row) =>
      Bookmark(id: row.integer('id'), url: Uri.parse(row.text('url')));

  static Map<String, Object?> _toRow(Bookmark bookmark) => {
        'id': bookmark.id,
        'url': bookmark.url.toString(),
      };
}
