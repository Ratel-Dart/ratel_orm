import 'package:ratel_orm/ratel_orm.dart';

import '../entities/not_an_entity.dart';

final class NotAnEntityRepository extends RatelRepository<NotAnEntity, int> {
  NotAnEntityRepository(super.driver);
}
