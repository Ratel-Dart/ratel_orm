import 'dart:typed_data';

import 'package:ratel_orm/ratel_orm.dart';
import 'package:ratel_orm/runtime.dart';
import 'package:test/test.dart';

import '../support/fixtures/definitions/gadget_definition.dart';
import '../support/fixtures/entities/gadget_kind.dart';

void main() {
  EntityRow row(Map<String, Object?> values) =>
      EntityRow(GadgetDefinition.value, values);

  Matcher mappingError(List<String> fragments) =>
      throwsA(isA<MappingException>().having(
        (error) => error.message,
        'message',
        allOf([for (final fragment in fragments) contains(fragment)]),
      ));

  group('fields and columns', () {
    test('reads a field from its column', () {
      expect(row({'display_name': 'lamp'}).text('name'), 'lamp');
      expect(row({'created_at': '2024-05-06T07:08:09Z'}).dateTime('createdAt'),
          DateTime.utc(2024, 5, 6, 7, 8, 9));
    });

    test('ignores a column keyed by the field name', () {
      expect(
        () => row({'name': 'lamp'}).text('name'),
        mappingError(['Gadget.name', '"display_name"', '"name"']),
      );
    });

    test('refuses a field that is not a column', () {
      expect(
        () => row({'selected': true}).boolean('selected'),
        mappingError(['Gadget', '"selected"']),
      );
    });

    test('refuses a missing column for a required value', () {
      expect(
        () => row({'id': 1}).text('name'),
        mappingError(['Gadget.name', 'no column', '"display_name"', '"id"']),
      );
    });

    test('says so when the row has no columns at all', () {
      expect(
        () => row({}).integer('id'),
        throwsA(isA<MappingException>().having(
          (error) => error.message,
          'message',
          'Cannot map Gadget.id: the row has no column "id" '
              '(the row has no columns).',
        )),
      );
    });

    test('accepts the one column that differs only in letter case', () {
      final declared = row({'ID': 3, 'Display_Name': 'lamp', 'NOTE': 'x'});
      expect(declared.integer('id'), 3);
      expect(declared.text('name'), 'lamp');
      expect(declared.textOrNull('note'), 'x');
    });

    test('prefers the exact column over one that differs in case', () {
      expect(
          row({'NOTE': 'upper', 'note': 'exact'}).textOrNull('note'), 'exact');
    });

    test('refuses columns that all differ from the name only in case', () {
      final ambiguous = row({'Note': 'a', 'NOTE': 'b'});
      final refused =
          mappingError(['Gadget.note', '"note"', '"Note", "NOTE"', 'case']);
      expect(() => ambiguous.textOrNull('note'), refused);
      expect(() => ambiguous.text('note'), refused);
    });

    test('reads a missing column as null for an optional value', () {
      final empty = row({});
      expect(empty.integerOrNull('id'), isNull);
      expect(empty.realOrNull('price'), isNull);
      expect(empty.numberOrNull('price'), isNull);
      expect(empty.textOrNull('note'), isNull);
      expect(empty.booleanOrNull('active'), isNull);
      expect(empty.dateTimeOrNull('createdAt'), isNull);
      expect(empty.bytesOrNull('payload'), isNull);
      expect(empty.enumerationOrNull('kind', GadgetKind.values), isNull);
    });

    test('reads a null value as null for an optional value', () {
      final nulls = row({'id': null, 'note': null, 'kind': null});
      expect(nulls.integerOrNull('id'), isNull);
      expect(nulls.textOrNull('note'), isNull);
      expect(nulls.enumerationOrNull('kind', GadgetKind.values), isNull);
    });

    test('refuses a null value for a required value', () {
      expect(
        () => row({'display_name': null}).text('name'),
        mappingError(
            ['Gadget.name', '"display_name"', 'a String', 'holds Null']),
      );
    });
  });

  group('integer', () {
    test('reads an int', () {
      expect(row({'id': 42}).integer('id'), 42);
      expect(row({'id': 42}).integerOrNull('id'), 42);
    });

    test('reads a BigInt that fits an int', () {
      expect(row({'id': BigInt.from(7)}).integer('id'), 7);
    });

    test('refuses a BigInt beyond an int', () {
      expect(
        () => row({'id': BigInt.parse('1' * 30)}).integer('id'),
        mappingError(['Gadget.id', '"id"', 'an int']),
      );
    });

    test('refuses text and fractions', () {
      expect(() => row({'id': '42'}).integer('id'),
          mappingError(['Gadget.id', 'holds String']));
      expect(() => row({'id': 4.2}).integerOrNull('id'),
          mappingError(['Gadget.id', 'holds double']));
    });
  });

  group('real', () {
    test('reads a double', () {
      expect(row({'price': 9.5}).real('price'), 9.5);
    });

    test('widens an int', () {
      final price = row({'price': 9}).real('price');
      expect(price, isA<double>());
      expect(price, 9.0);
    });

    test('parses numeric text such as a Postgres numeric', () {
      expect(row({'price': '12.50'}).real('price'), 12.5);
      expect(row({'price': '-3'}).realOrNull('price'), -3.0);
    });

    test('refuses text that is not a number', () {
      expect(
        () => row({'price': 'cheap'}).real('price'),
        mappingError(['Gadget.price', '"price"', 'numeric text', 'String']),
      );
    });

    test('refuses a bool', () {
      expect(() => row({'price': true}).real('price'),
          mappingError(['Gadget.price', 'holds bool']));
    });
  });

  group('number', () {
    test('keeps an int or a double as it is', () {
      expect(row({'price': 3}).number('price'), allOf(isA<int>(), 3));
      expect(row({'price': 3.5}).number('price'), 3.5);
    });

    test('parses numeric text', () {
      expect(row({'price': '7'}).number('price'), 7);
      expect(row({'price': '7.25'}).numberOrNull('price'), 7.25);
    });

    test('refuses text that is not a number', () {
      expect(() => row({'price': 'seven'}).number('price'),
          mappingError(['Gadget.price', 'holds String']));
    });
  });

  group('text', () {
    test('reads a String', () {
      expect(row({'note': 'fragile'}).text('note'), 'fragile');
      expect(row({'note': ''}).textOrNull('note'), '');
    });

    test('refuses a value that is not a String', () {
      expect(() => row({'note': 5}).textOrNull('note'),
          mappingError(['Gadget.note', '"note"', 'a String', 'holds int']));
    });
  });

  group('boolean', () {
    test('reads a bool', () {
      expect(row({'active': true}).boolean('active'), isTrue);
      expect(row({'active': false}).booleanOrNull('active'), isFalse);
    });

    test('reads SQLite 1 and 0', () {
      expect(row({'active': 1}).boolean('active'), isTrue);
      expect(row({'active': 0}).boolean('active'), isFalse);
    });

    test('refuses other ints and text', () {
      expect(() => row({'active': 2}).boolean('active'),
          mappingError(['Gadget.active', '0 or 1', 'holds int']));
      expect(() => row({'active': 'true'}).boolean('active'),
          mappingError(['Gadget.active', 'holds String']));
    });
  });

  group('dateTime', () {
    final instant = DateTime.utc(2024, 5, 6, 7, 8, 9, 10);

    test('keeps a DateTime as it is', () {
      final local = instant.toLocal();
      expect(row({'created_at': local}).dateTime('createdAt'), same(local));
    });

    test('parses ISO-8601 text as SQLite stores it', () {
      final read =
          row({'created_at': '2024-05-06T07:08:09.010Z'}).dateTime('createdAt');
      expect(read, instant);
      expect(read.isUtc, isTrue);
    });

    test('parses an offset to the same instant', () {
      final read = row({'created_at': '2024-05-06T09:08:09.010+02:00'})
          .dateTimeOrNull('createdAt');
      expect(read!.isAtSameMomentAs(instant), isTrue);
    });

    test('reads text without an offset as UTC, as SQLite writes it', () {
      expect(
        row({'created_at': '2024-05-06 07:08:09'}).dateTime('createdAt'),
        DateTime.utc(2024, 5, 6, 7, 8, 9),
      );
      expect(
        row({'created_at': '2024-05-06'}).dateTime('createdAt'),
        DateTime.utc(2024, 5, 6),
      );
    });

    test('refuses text that is not a date and other values', () {
      expect(
        () => row({'created_at': 'yesterday'}).dateTime('createdAt'),
        mappingError(
            ['Gadget.createdAt', '"created_at"', 'ISO-8601', 'holds String']),
      );
      expect(() => row({'created_at': 1714979289}).dateTime('createdAt'),
          mappingError(['Gadget.createdAt', 'holds int']));
    });
  });

  group('bytes', () {
    test('keeps a Uint8List as it is', () {
      final payload = Uint8List.fromList([1, 2, 3]);
      expect(row({'payload': payload}).bytes('payload'), same(payload));
    });

    test('copies a List<int> into a Uint8List', () {
      final read = row({
        'payload': <int>[4, 5]
      }).bytesOrNull('payload');
      expect(read, isA<Uint8List>());
      expect(read, [4, 5]);
    });

    test('refuses text', () {
      expect(() => row({'payload': 'AQID'}).bytes('payload'),
          mappingError(['Gadget.payload', 'Uint8List', 'holds String']));
    });
  });

  group('enumeration', () {
    test('reads an enum by its name', () {
      expect(
        row({'kind': 'toy'}).enumeration('kind', GadgetKind.values),
        GadgetKind.toy,
      );
      expect(
        row({'kind': 'tool'}).enumerationOrNull('kind', GadgetKind.values),
        GadgetKind.tool,
      );
    });

    test('refuses a name the enum does not have', () {
      expect(
        () => row({'kind': 'TOY'}).enumeration('kind', GadgetKind.values),
        mappingError(
            ['Gadget.kind', '"kind"', 'GadgetKind', 'tool, toy', 'String']),
      );
    });

    test('refuses a value that is not text', () {
      expect(
        () => row({'kind': 1}).enumeration('kind', GadgetKind.values),
        mappingError(['Gadget.kind', 'holds int']),
      );
    });
  });

  test('feeds a hand-built fromRow', () {
    final gadget = GadgetDefinition.value.fromRow(row({
      'id': 5,
      'display_name': 'lamp',
      'kind': 'tool',
      'active': 1,
      'price': 12,
      'created_at': '2024-05-06T07:08:09.000Z',
      'note': null,
      'payload': Uint8List.fromList([9]),
    }));
    expect(gadget.id, 5);
    expect(gadget.name, 'lamp');
    expect(gadget.kind, GadgetKind.tool);
    expect(gadget.active, isTrue);
    expect(gadget.price, 12.0);
    expect(gadget.createdAt, DateTime.utc(2024, 5, 6, 7, 8, 9));
    expect(gadget.note, isNull);
    expect(gadget.payload, [9]);
    expect(gadget.selected, isFalse);
  });
}
