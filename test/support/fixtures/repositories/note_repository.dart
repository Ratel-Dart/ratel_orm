import 'package:ratel_orm/ratel_orm.dart';

import '../entities/note.dart';

final class NoteRepository extends RatelRepository<Note, int> {
  NoteRepository(super.driver);

  Future<List<Note>> add(int id, String body) => execute(
        'INSERT INTO notes (id, body) VALUES (@id, @body)',
        parameters: {'id': id, 'body': body},
        returning: true,
      );
}
