import 'dart:async';

import 'package:ratel_orm/ratel_orm.dart';
import 'package:ratel_orm/testing.dart';
import 'package:test/test.dart';

import '../support/driver_conformance.dart';

void main() {
  DriverConformance.run(FakeDriver.new);

  test('a transaction begun after the outer one ended gets its own session',
      () async {
    final driver = FakeDriver();
    final ended = Completer<void>();
    late RatelSession first;
    late Future<RatelSession> afterwards;

    await driver.transaction((session) async {
      first = session;
      afterwards = ended.future.then(
        (_) => driver.transaction((later) async => later),
      );
    });
    ended.complete();
    expect(await afterwards, isNot(same(first)));
  });

  test('a nested transaction lets an error through unchanged', () async {
    final driver = FakeDriver();
    final error = StateError('boom');

    await expectLater(
      driver.transaction<void>((outer) {
        return driver.transaction<void>((inner) async => throw error);
      }),
      throwsA(same(error)),
    );
  });
}
