import 'package:ratel_orm/ratel_orm.dart';

import '../entities/widget.dart';

final class WidgetRepository extends RatelRepository<Widget, int> {
  WidgetRepository(super.driver);

  Future<List<Widget>> named(String name) => execute(
        'SELECT * FROM widgets WHERE name = @name',
        parameters: {'name': name},
      );
}
