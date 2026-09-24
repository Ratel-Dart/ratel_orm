import 'package:ratel_orm/ratel_orm.dart';

import '../entities/person.dart';

final class PersonRepository extends RatelRepository<Person, int> {
  PersonRepository(super.driver);
}
