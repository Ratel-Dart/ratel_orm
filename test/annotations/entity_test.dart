import 'package:ratel_orm/ratel_orm.dart';
import 'package:test/test.dart';

void main() {
  test('leaves the table to the naming rules by default', () {
    const entity = Entity();
    expect(entity.table, isNull);
  });

  test('carries an explicit table name', () {
    const entity = Entity(table: 'gadgets');
    expect(entity.table, 'gadgets');
  });
}
