import 'package:ratel_orm/runtime.dart';
import 'package:test/test.dart';

import '../support/fixtures/definitions/gadget_definition.dart';
import '../support/test_entities.dart';

void main() {
  test('publishes contract 1 for generated code', () {
    expect(RatelOrmRuntime.contract, 1);
  });

  test('validates, then installs a manifest once per isolate', () {
    expect(RatelOrmRuntime.installed, isNull);

    expect(
      () => RatelOrmRuntime.install(
        const EntityManifest(
          entities: [GadgetDefinition.value, GadgetDefinition.value],
        ),
      ),
      throwsA(isA<StateError>().having(
        (error) => error.message,
        'message',
        contains('Gadget'),
      )),
    );
    expect(RatelOrmRuntime.installed, isNull);

    TestEntities.install();
    TestEntities.install();
    expect(RatelOrmRuntime.installed, same(TestEntities.manifest));

    expect(
      () => RatelOrmRuntime.install(EntityManifest(entities: [])),
      throwsStateError,
    );
    expect(RatelOrmRuntime.installed, same(TestEntities.manifest));
  });
}
