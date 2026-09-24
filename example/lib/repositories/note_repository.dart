import 'package:ratel_orm/ratel_orm.dart';

import '../entities/note.dart';

final class NoteRepository extends RatelRepository<Note, int> {
  NoteRepository(super.driver);

  Future<List<Note>> pinned() =>
      find(Query.from(table).where('pinned', '=', true).orderBy('id'));
}
