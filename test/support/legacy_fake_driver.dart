import 'package:ratel_orm/ratel_orm.dart';
import 'package:ratel_orm/testing.dart';

import 'legacy_sqlite_dialect.dart';

final class LegacyFakeDriver extends FakeDriver {
  final List<String> statements = [];

  @override
  SqlDialect get dialect => const LegacySqliteDialect();

  @override
  Future<QueryResult> query(String sql, {Map<String, Object?>? parameters}) {
    statements.add(sql);
    return super.query(sql, parameters: parameters);
  }
}
