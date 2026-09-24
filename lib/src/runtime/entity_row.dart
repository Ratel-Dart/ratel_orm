import 'dart:typed_data';

import '../exceptions/mapping_exception.dart';
import 'entity_definition.dart';
import 'entity_mapping.dart';

final class EntityRow {
  EntityRow(EntityDefinition<Object> entity, Map<String, Object?> values)
      : _mapping = EntityMapping.of(entity),
        _values = values;

  final EntityMapping _mapping;
  final Map<String, Object?> _values;

  int integer(String field) => _required(field, 'an int', _integer);

  int? integerOrNull(String field) => _optional(field, 'an int', _integer);

  double real(String field) => _required(field, _realForms, _real);

  double? realOrNull(String field) => _optional(field, _realForms, _real);

  num number(String field) => _required(field, _numberForms, _number);

  num? numberOrNull(String field) => _optional(field, _numberForms, _number);

  String text(String field) => _required(field, 'a String', _text);

  String? textOrNull(String field) => _optional(field, 'a String', _text);

  bool boolean(String field) => _required(field, _booleanForms, _boolean);

  bool? booleanOrNull(String field) =>
      _optional(field, _booleanForms, _boolean);

  DateTime dateTime(String field) =>
      _required(field, _dateTimeForms, _dateTime);

  DateTime? dateTimeOrNull(String field) =>
      _optional(field, _dateTimeForms, _dateTime);

  Uint8List bytes(String field) => _required(field, _bytesForms, _bytes);

  Uint8List? bytesOrNull(String field) => _optional(field, _bytesForms, _bytes);

  E enumeration<E extends Enum>(String field, List<E> values) => _required(
        field,
        _enumerationForms(values),
        (value) => _enumeration(value, values),
      );

  E? enumerationOrNull<E extends Enum>(String field, List<E> values) =>
      _optional(
        field,
        _enumerationForms(values),
        (value) => _enumeration(value, values),
      );

  static const String _realForms = 'a double, an int or numeric text';

  static const String _numberForms = 'a num or numeric text';

  static const String _booleanForms = 'a bool or the int 0 or 1';

  static const String _dateTimeForms = 'a DateTime or ISO-8601 text';

  static const String _bytesForms = 'a Uint8List or List<int>';

  T _required<T extends Object>(
    String field,
    String expected,
    T? Function(Object value) convert,
  ) {
    final column = _mapping.columnOf(field);
    final key = _keyOf(field, column);
    if (key == null) {
      final present = _values.isEmpty
          ? 'the row has no columns'
          : 'it has ${_values.keys.map((key) => '"$key"').join(', ')}';
      throw MappingException(
        'Cannot map ${_mapping.entity}.$field: the row has no column '
        '"$column" ($present).',
      );
    }
    final value = _values[key];
    final converted = value == null ? null : convert(value);
    return converted ?? (throw _unconvertible(field, column, expected, value));
  }

  T? _optional<T extends Object>(
    String field,
    String expected,
    T? Function(Object value) convert,
  ) {
    final column = _mapping.columnOf(field);
    final key = _keyOf(field, column);
    final value = key == null ? null : _values[key];
    if (value == null) return null;
    return convert(value) ??
        (throw _unconvertible(field, column, expected, value));
  }

  String? _keyOf(String field, String column) {
    if (_values.containsKey(column)) return column;
    final folded = column.toLowerCase();
    final matches = [
      for (final key in _values.keys)
        if (key.toLowerCase() == folded) key,
    ];
    if (matches.length > 1) {
      throw MappingException(
        'Cannot map ${_mapping.entity}.$field: the row has no column '
        '"$column", and ${matches.map((key) => '"$key"').join(', ')} differ '
        'from it only in letter case.',
      );
    }
    return matches.isEmpty ? null : matches.single;
  }

  MappingException _unconvertible(
    String field,
    String column,
    String expected,
    Object? value,
  ) =>
      MappingException(
        'Cannot map ${_mapping.entity}.$field from the column "$column": '
        'expected $expected, but the row holds ${value.runtimeType}.',
      );

  static String _enumerationForms<E extends Enum>(List<E> values) =>
      'the name of a $E (${values.map((value) => value.name).join(', ')})';

  static int? _integer(Object value) => switch (value) {
        int() => value,
        BigInt() when value.isValidInt => value.toInt(),
        _ => null,
      };

  static double? _real(Object value) => switch (value) {
        double() => value,
        int() => value.toDouble(),
        String() => double.tryParse(value),
        _ => null,
      };

  static num? _number(Object value) => switch (value) {
        num() => value,
        String() => num.tryParse(value),
        _ => null,
      };

  static String? _text(Object value) => value is String ? value : null;

  static bool? _boolean(Object value) => switch (value) {
        bool() => value,
        int() when value == 0 => false,
        int() when value == 1 => true,
        _ => null,
      };

  static DateTime? _dateTime(Object value) => switch (value) {
        DateTime() => value,
        String() => _parseDateTime(value),
        _ => null,
      };

  static DateTime? _parseDateTime(String text) {
    final parsed = DateTime.tryParse(text);
    if (parsed == null || parsed.isUtc) return parsed;
    return DateTime.tryParse('${text}Z') ?? DateTime.tryParse('${text}T00Z');
  }

  static Uint8List? _bytes(Object value) => switch (value) {
        Uint8List() => value,
        List<int>() => Uint8List.fromList(value),
        _ => null,
      };

  static E? _enumeration<E extends Enum>(Object value, List<E> values) {
    if (value is! String) return null;
    for (final candidate in values) {
      if (candidate.name == value) return candidate;
    }
    return null;
  }
}
