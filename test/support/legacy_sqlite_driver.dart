import 'package:ratel_orm/ratel_orm.dart';
import 'package:ratel_orm/sqlite.dart';

import 'legacy_sqlite_dialect.dart';

final class LegacySqliteDriver extends SqliteDriver {
  LegacySqliteDriver() : super(':memory:');

  @override
  SqlDialect get dialect => const LegacySqliteDialect();
}
