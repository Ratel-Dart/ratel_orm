import 'package:ratel_orm/src/runtime/sql_names.dart';
import 'package:test/test.dart';

void main() {
  test('snake_cases class and field names', () {
    expect(SqlNames.of('UserAccount'), 'user_account');
    expect(SqlNames.of('createdAt'), 'created_at');
    expect(SqlNames.of('Gadget'), 'gadget');
    expect(SqlNames.of('id'), 'id');
  });

  test('keeps acronyms together', () {
    expect(SqlNames.of('userID'), 'user_id');
    expect(SqlNames.of('HTTPServer'), 'http_server');
    expect(SqlNames.of('IOStream'), 'io_stream');
    expect(SqlNames.of('URL'), 'url');
  });

  test('splits after a digit but not before one', () {
    expect(SqlNames.of('address2Line'), 'address2_line');
    expect(SqlNames.of('version2'), 'version2');
  });

  test('leaves snake_case untouched and does not pluralize', () {
    expect(SqlNames.of('already_snake'), 'already_snake');
    expect(SqlNames.of('Person'), 'person');
  });
}
