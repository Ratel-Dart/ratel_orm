import '../driver/query_result.dart';
import '../driver/ratel_session.dart';
import 'fake_driver.dart';

class FakeSession implements RatelSession {
  final FakeDriver _driver;

  bool _open = true;

  FakeSession(this._driver);

  bool get isOpen => _open;

  void close() => _open = false;

  @override
  Future<QueryResult> query(String sql, {Map<String, Object?>? parameters}) =>
      _driver.query(sql, parameters: parameters);
}
