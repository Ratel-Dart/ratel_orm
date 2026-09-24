import 'package:ratel_orm/ratel_orm.dart';
import 'package:test/test.dart';

void main() {
  test('is a canonical const marker', () {
    expect(identical(const Transient(), const Transient()), isTrue);
  });
}
