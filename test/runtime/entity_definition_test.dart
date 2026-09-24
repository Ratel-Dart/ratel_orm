import 'package:ratel_orm/runtime.dart';
import 'package:test/test.dart';

import '../support/fixtures/definitions/gadget_definition.dart';
import '../support/fixtures/entities/gadget.dart';
import '../support/fixtures/entities/gadget_kind.dart';

void main() {
  final gadget = Gadget(
    id: 3,
    name: 'lamp',
    kind: GadgetKind.tool,
    active: true,
    price: 9.5,
    createdAt: DateTime.utc(2024, 5, 6),
  );

  test('reports the entity type it maps', () {
    expect(GadgetDefinition.value.type, Gadget);
  });

  test('rowOf reads an entity through an erased definition', () {
    const EntityDefinition<Object> erased = GadgetDefinition.value;
    final row = erased.rowOf(gadget);
    expect(row['id'], 3);
    expect(row['name'], 'lamp');
    expect(row['kind'], 'tool');
    expect(row.containsKey('selected'), isFalse);
  });

  test('toRow cannot be read through an erased definition', () {
    const EntityDefinition<Object> erased = GadgetDefinition.value;
    expect(() => erased.toRow, throwsA(isA<TypeError>()));
  });

  test('rowOf rejects an entity of another type', () {
    const EntityDefinition<Object> erased = GadgetDefinition.value;
    expect(() => erased.rowOf('not a gadget'), throwsA(isA<TypeError>()));
  });
}
