import 'package:ratel_orm/ratel_orm.dart';

import '../entities/labeled_widget.dart';

final class LabeledWidgetRepository
    extends RatelRepository<LabeledWidget, int> {
  LabeledWidgetRepository(super.driver);

  Future<List<LabeledWidget>> add(int id, String label) => execute(
        'INSERT INTO ratel_repo_widgets (id, label) VALUES (@id, @label)',
        parameters: {'id': id, 'label': label},
        returning: true,
      );
}
