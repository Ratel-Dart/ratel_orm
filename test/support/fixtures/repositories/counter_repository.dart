import 'package:ratel_orm/ratel_orm.dart';

import '../entities/counter.dart';

final class CounterRepository extends RatelRepository<Counter, int> {
  CounterRepository(super.driver);
}
