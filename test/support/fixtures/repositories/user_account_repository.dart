import 'package:ratel_orm/ratel_orm.dart';

import '../entities/user_account.dart';

final class UserAccountRepository extends RatelRepository<UserAccount, int> {
  UserAccountRepository(super.driver);
}
