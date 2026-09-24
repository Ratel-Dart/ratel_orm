import 'package:ratel_orm/ratel_orm.dart';

@Entity(table: 'notes')
final class Note {
  const Note({
    this.id,
    required this.body,
    required this.createdAt,
    this.pinned = false,
  });

  @Id()
  final int? id;
  final String body;
  final DateTime createdAt;
  final bool pinned;
}
