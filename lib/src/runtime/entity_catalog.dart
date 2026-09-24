import 'entity_manifest.dart';
import 'entity_mapping.dart';

final class EntityCatalog {
  EntityCatalog._(this.manifest, this._byType);

  static final Expando<EntityCatalog> _catalogs = Expando('EntityCatalog');

  static EntityCatalog of(EntityManifest manifest) =>
      _catalogs[manifest] ??= _build(manifest);

  final EntityManifest manifest;
  final Map<Type, EntityMapping> _byType;

  Iterable<EntityMapping> get entities => _byType.values;

  EntityMapping? lookup(Type type) => _byType[type];

  static EntityCatalog _build(EntityManifest manifest) {
    final byType = <Type, EntityMapping>{};
    for (final definition in manifest.entities) {
      final mapping = EntityMapping.of(definition);
      final previous = byType[mapping.type];
      if (previous != null) {
        throw StateError(
          'The entity type ${mapping.type} is listed twice in the Ratel ORM '
          'entity manifest, as ${previous.entity} and ${mapping.entity}.',
        );
      }
      byType[mapping.type] = mapping;
    }
    return EntityCatalog._(manifest, Map.unmodifiable(byType));
  }
}
