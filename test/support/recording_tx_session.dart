import 'dart:async';

import 'package:postgres/postgres.dart';

class RecordingTxSession implements TxSession {
  bool open = true;

  Object? lastParameters;

  @override
  bool get isOpen => open;

  @override
  Future<void> get closed => Completer<void>().future;

  @override
  Future<Statement> prepare(Object query) => throw UnsupportedError('prepare');

  @override
  Future<Result> execute(
    Object query, {
    Object? parameters,
    bool ignoreRows = false,
    QueryMode? queryMode,
    Duration? timeout,
  }) async {
    lastParameters = parameters;
    return Result(rows: const [], affectedRows: 0, schema: ResultSchema([]));
  }

  @override
  Future<void> rollback() async {}
}
