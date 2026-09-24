abstract final class PostgresParameters {
  static Map<String, Object?> bindable(Map<String, Object?> parameters) => {
        for (final MapEntry(:key, :value) in parameters.entries)
          key: value is DateTime ? value.toUtc() : value,
      };
}
