import 'package:ratel_orm/ratel_orm.dart';

import '../entities/gadget.dart';

final class GadgetRepository extends RatelRepository<Gadget, int> {
  GadgetRepository(super.driver);
}
