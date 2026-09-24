import 'package:ratel_orm/ratel_orm.dart';

import '../entities/bookmark.dart';

final class BookmarkRepository extends RatelRepository<Bookmark, int> {
  BookmarkRepository(super.driver);
}
