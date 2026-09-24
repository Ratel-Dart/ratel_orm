import 'package:ratel_orm/ratel_orm.dart';

@Entity(table: 'bookmarks')
final class Bookmark {
  const Bookmark({required this.id, required this.url});

  @Id()
  final int id;
  final Uri url;
}
