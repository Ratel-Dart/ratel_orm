import 'package:ratel_orm/runtime.dart';

import '../entities/user_account.dart';

abstract final class UserAccountDefinition {
  static const value = EntityDefinition<UserAccount>(
    name: 'UserAccount',
    columns: [
      ColumnDefinition(field: 'userID', isId: true),
      ColumnDefinition(field: 'emailAddress'),
      ColumnDefinition(field: 'lastLoginAt'),
    ],
    fromRow: _fromRow,
    toRow: _toRow,
  );

  static UserAccount _fromRow(EntityRow row) => UserAccount(
        userID: row.integer('userID'),
        emailAddress: row.text('emailAddress'),
        lastLoginAt: row.dateTimeOrNull('lastLoginAt'),
      );

  static Map<String, Object?> _toRow(UserAccount account) => {
        'userID': account.userID,
        'emailAddress': account.emailAddress,
        'lastLoginAt': account.lastLoginAt,
      };
}
