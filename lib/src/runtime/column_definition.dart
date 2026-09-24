final class ColumnDefinition {
  const ColumnDefinition({required this.field, this.name, this.isId = false});

  final String field;
  final String? name;
  final bool isId;
}
