import 'package:ratel_orm/ratel_orm.dart';

@Entity(table: 'notes')
final class Note {
  const Note({required this.id, required this.body});

  @Id()
  final int id;
  final String body;
}
