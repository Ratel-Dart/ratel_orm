import 'entity_catalog.dart';
import 'entity_manifest.dart';

abstract final class RatelOrmRuntime {
  static const int contract = 1;

  static EntityManifest? _installed;

  static EntityManifest? get installed => _installed;

  static void install(EntityManifest manifest) {
    final current = _installed;
    if (current == null) {
      EntityCatalog.of(manifest);
      _installed = manifest;
      return;
    }
    if (identical(current, manifest)) return;
    throw StateError(
      'A different Ratel ORM entity manifest is already installed in this '
      'isolate.',
    );
  }
}
