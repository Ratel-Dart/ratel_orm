import 'package:ratel_orm/ratel_orm.dart';
import 'package:test/test.dart';

void main() {
  test('leaves the column name to the naming rules by default', () {
    const column = Column();
    expect(column.name, isNull);
  });

  test('carries an explicit column name', () {
    const column = Column(name: 'display_name');
    expect(column.name, 'display_name');
  });
}
