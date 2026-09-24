import 'package:postgres/postgres.dart';

import '../driver/query_result.dart';
import '../driver/ratel_session.dart';
import '../exceptions/query_execution_exception.dart';
import 'postgres_parameters.dart';
import 'postgres_result_mapper.dart';

class PostgresSession implements RatelSession {
  final TxSession _tx;

  PostgresSession(this._tx);

  bool get isOpen => _tx.isOpen;

  @override
  Future<QueryResult> query(String sql,
      {Map<String, Object?>? parameters}) async {
    try {
      final result = (parameters == null || parameters.isEmpty)
          ? await _tx.execute(sql)
          : await _tx.execute(
              Sql.named(sql),
              parameters: PostgresParameters.bindable(parameters),
            );
      return PostgresResultMapper.toQueryResult(result);
    } catch (e) {
      throw QueryExecutionException('Postgres query failed',
          sql: sql, cause: e);
    }
  }
}
