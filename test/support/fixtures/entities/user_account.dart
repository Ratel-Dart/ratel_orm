import 'package:ratel_orm/ratel_orm.dart';

@Entity()
final class UserAccount {
  const UserAccount({
    required this.userID,
    required this.emailAddress,
    this.lastLoginAt,
  });

  @Id()
  final int userID;
  final String emailAddress;
  final DateTime? lastLoginAt;
}
