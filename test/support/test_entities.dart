import 'package:ratel_orm/runtime.dart';

import 'fixtures/definitions/bookmark_definition.dart';
import 'fixtures/definitions/counter_definition.dart';
import 'fixtures/definitions/gadget_definition.dart';
import 'fixtures/definitions/labeled_widget_definition.dart';
import 'fixtures/definitions/note_definition.dart';
import 'fixtures/definitions/person_definition.dart';
import 'fixtures/definitions/user_account_definition.dart';
import 'fixtures/definitions/widget_definition.dart';

abstract final class TestEntities {
  static const manifest = EntityManifest(
    entities: [
      GadgetDefinition.value,
      UserAccountDefinition.value,
      WidgetDefinition.value,
      NoteDefinition.value,
      PersonDefinition.value,
      LabeledWidgetDefinition.value,
      BookmarkDefinition.value,
      CounterDefinition.value,
    ],
  );

  static void install() => RatelOrmRuntime.install(manifest);
}
