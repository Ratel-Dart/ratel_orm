import 'dart:typed_data';

import 'package:ratel_orm/src/postgres/postgres_parameters.dart';
import 'package:test/test.dart';

void main() {
  test('binds a DateTime as the same instant in UTC', () {
    final instant = DateTime.utc(2024, 5, 6, 7, 8, 9, 10, 11);
    final bound = PostgresParameters.bindable({
      'local': instant.toLocal(),
      'utc': instant,
    });
    for (final value in bound.values) {
      expect(value, isA<DateTime>());
      expect((value! as DateTime).isUtc, isTrue);
      expect(value, instant);
    }
  });

  test('leaves every other value as it is', () {
    final bytes = Uint8List.fromList([1, 2]);
    final ids = [1, 2, 3];
    final bound = PostgresParameters.bindable({
      'none': null,
      'flag': true,
      'count': 3,
      'price': 2.5,
      'name': 'ada',
      'bytes': bytes,
      'ids': ids,
    });
    expect(
        bound.keys, ['none', 'flag', 'count', 'price', 'name', 'bytes', 'ids']);
    expect(bound['none'], isNull);
    expect(bound['flag'], isTrue);
    expect(bound['count'], 3);
    expect(bound['price'], 2.5);
    expect(bound['name'], 'ada');
    expect(bound['bytes'], same(bytes));
    expect(bound['ids'], same(ids));
  });
}
