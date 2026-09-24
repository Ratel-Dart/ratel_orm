import 'entity_definition.dart';

final class EntityManifest {
  const EntityManifest({this.entities = const []});

  final List<EntityDefinition<Object>> entities;
}
