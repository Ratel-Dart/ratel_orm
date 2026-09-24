import 'package:ratel_orm/ratel_orm.dart';

final class LegacySqliteDialect extends SqliteDialect {
  const LegacySqliteDialect();

  @override
  bool get supportsReturning => false;
}
