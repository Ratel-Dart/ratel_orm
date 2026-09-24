<h1 align="center">Ratel ORM</h1>

A standalone SQL toolkit for Dart: a driver contract with Postgres and SQLite
drivers, CRUD repositories for `@Entity` classes, a query builder and
migrations.

It depends on no web framework. It works in a CLI, a worker or a test, and it
works next to [Ratel](https://github.com/Ratel-Dart/Ratel) the way Prisma works
next to NestJS: the two fit together, and neither needs the other.

## What it provides

- **Entities**: JPA-style annotations (`@Entity`, `@Id`, `@Column`,
  `@Transient`) describe how a class maps to a table.
- **`RatelRepository<T, ID>`**: `findAll`, `findById`, `insert`, `update` and
  `deleteById` for an entity. It also has `execute` for your own SQL with
  `@name` parameters and an opt-in `returning:`, and `find` for queries made
  with the query builder.
- **Query builder**: `Query.from(...).select(...).where(...).orderBy(...)`,
  rendered for each dialect.
- **Dialect layer**: identifier quoting, `LIMIT`/`OFFSET` and `RETURNING`
  for Postgres and SQLite.
- **Migrations**: an ordered `Migrator` with a bookkeeping table. Each
  migration runs in its own transaction.
- **Drivers**, each in its own sub-library, so each client package is imported
  in only one place:
  - `package:ratel_orm/postgres.dart`: `PostgresDriver`, with a connection
    pool and `PostgresDriver.fromEnv()`
  - `package:ratel_orm/sqlite.dart`: `SqliteDriver`, including `.memory()`
- **Runtime**: `package:ratel_orm/runtime.dart` provides `RatelOrmRuntime`,
  `EntityManifest`, `EntityDefinition`, `ColumnDefinition` and `EntityRow`,
  for generated code, isolates you spawn yourself and hand-built test
  manifests.
- **Test support**: `package:ratel_orm/testing.dart` provides a `FakeDriver`,
  so you can test ORM logic without a database.

## Entities

An `@Entity` class is a table. The ORM knows the table's shape from the
annotations:

```dart
import 'package:ratel_orm/ratel_orm.dart';

enum Role { member, admin }

@Entity(table: 'users')
final class User {
  const User({
    this.id,
    required this.email,
    required this.role,
    required this.createdAt,
    this.lastLoginAt,
    this.selected = false,
  });

  @Id()
  final int? id;
  @Column(name: 'email_address')
  final String email;
  final Role role;
  final DateTime createdAt;
  final DateTime? lastLoginAt;
  @Transient()
  final bool selected;

  bool get isAdmin => role == Role.admin;
}
```

- Every public instance field is a column unless it is marked `@Transient()`.
  That includes inherited fields and fields declared by a primary
  constructor. Getters are never columns.
- An entity has exactly one `@Id()` field.
- If the `@Id()` field is nullable and null on insert, the ORM leaves it out
  of the `INSERT`. The database generates the id, and `RETURNING` maps it
  back onto the entity that `insert` returns. A non-null id is always
  inserted.

### Naming

The ORM derives table and column names when the app runs. It does not
pluralize.

| Declared as | Name | Example |
| --- | --- | --- |
| class | snake_case of the class name | `UserAccount` → `user_account` |
| field | snake_case of the field name | `createdAt` → `created_at` |
| acronyms | kept together | `userID` → `user_id`, `HTTPServer` → `http_server` |
| `@Entity(table: 'users')` | the given table name | `users` |
| `@Column(name: 'email_address')` | the given column name | `email_address` |

So the `User` above maps to the table `users` with the columns `id`,
`email_address`, `role`, `created_at` and `last_login_at`.

Every name is quoted as one identifier, and a `"` inside it is doubled. So
`@Entity(table: 'app.users')` names a table called `app.users`, not the table
`users` in the schema `app`. Schema-qualified names are not supported; put
the schema on the Postgres `search_path` instead.

## Repositories

A repository takes its driver in the constructor. Add your own queries next to
the CRUD methods it inherits:

```dart
import 'package:ratel_orm/ratel_orm.dart';

final class UserRepository extends RatelRepository<User, int> {
  UserRepository(super.driver);

  Future<List<User>> admins() => execute(
        'SELECT * FROM users WHERE role = @role',
        parameters: {'role': Role.admin.name},
      );
}
```

```dart
import 'package:ratel_orm/postgres.dart';

Future<void> main() async {
  final driver = PostgresDriver.fromEnv();
  await driver.open();
  final users = UserRepository(driver);

  final ada = await users.insert(User(
    email: 'ada@example.com',
    role: Role.admin,
    createdAt: DateTime.now(),
  ));
  print(await users.findById(ada.id!));
  await users.deleteById(ada.id!);
  await driver.close();
}
```

Every statement quotes its identifiers and names each column explicitly
(never `*`):

| Method | SQL for `User` | Result |
| --- | --- | --- |
| `findAll()` | `SELECT "id", "email_address", ... FROM "users"` | every row |
| `findById(id)` | `SELECT ... FROM "users" WHERE "id" = @id` | the entity, or `null` |
| `insert(user)` | `INSERT INTO "users" ("email_address", ...) VALUES (@c0, ...) RETURNING "id", ...` | the entity as stored, with its generated id |
| `update(user)` | `UPDATE "users" SET "email_address" = @c0, ... WHERE "id" = @id RETURNING ...` | the entity as stored, or `null` if no row matched |
| `deleteById(id)` | `DELETE FROM "users" WHERE "id" = @id` | `true` if a row was deleted |
| `execute(sql)` | your SQL | the mapped rows, or an empty list |
| `find(query)` | the query builder's SQL | the mapped rows, or an empty list |

- `update` throws an `ArgumentError` if the entity's id is null.
- If an entity has only an id, `insert` uses `DEFAULT VALUES` when the id is
  null, and `update` has nothing to write, so it reads the row back by its id
  instead.
- Rows are mapped by column name, so SQL you pass to `execute` must return
  the entity's columns, for example with `SELECT *`. The name must match
  exactly. When no column does, a single column whose name differs only in
  letter case is accepted, because SQLite returns column names as the
  `CREATE TABLE` spelled them.
- A dialect without `RETURNING` inserts first and then reads the row back by
  its id, or by the driver's `lastInsertId` when the database generated the
  id.

The repository looks up its entity when you construct it. It throws a
`StateError` if no entity manifest is installed, or if `T` is not an entity
in the installed manifest.

### Transactions

A repository keeps its driver. Queries sent through that driver from inside
the action of `driver.transaction`, including every call on a repository
built on it, run in that transaction on both drivers: they see its
uncommitted rows and roll back with it.

```dart
await driver.transaction((session) async {
  final ada = await users.insert(User(
    email: 'ada@example.com',
    role: Role.member,
    createdAt: DateTime.now(),
  ));
  await session.query(
    'INSERT INTO audit (user_id) VALUES (@id)',
    parameters: {'id': ada.id},
  );
});
```

Calls made from anywhere else do not join the transaction. On SQLite they
wait until it ends. On Postgres they run on another pooled connection.

## Mappers come from the ratel CLI

Dart has no reflection under AOT compilation, and this package does not use
`build_runner`. The `ratel` CLI generates the row mappers instead. It reads
your `@Entity` classes, builds a const `EntityManifest` and installs it before
your app's `main` runs:

```sh
dart pub global activate ratel_cli
ratel dev
ratel build
ratel test
```

Plain `dart run`, `dart compile exe` and `dart test` skip that step. The
first repository you construct then fails loudly with a `StateError` that
explains this. The ORM never falls back to guessing a mapping.

Generation needs a `ratel_cli` release that supports the ORM runtime
contract `RatelOrmRuntime.contract` (currently `1`). Until you have one,
build the definitions by hand and install the manifest yourself with
`RatelOrmRuntime.install`, as shown under [Testing](#testing).

**Isolates.** The manifest is installed per isolate. The CLI installs it in
the main isolate. In an isolate you spawn yourself, call
`RatelOrmRuntime.install(...)` from `package:ratel_orm/runtime.dart` with the
same manifest before you construct a repository. Installing the identical
manifest again does nothing. Installing a different manifest throws a
`StateError`.

## Value conversions

The generated `fromRow` reads each field through `EntityRow`, which converts
what the driver returns. The generated `toRow` turns an enum into its `.name`
before binding.

| Dart field | `EntityRow` accessor | Postgres column | SQLite column |
| --- | --- | --- | --- |
| `int` | `integer` | `integer`, `bigint`, identity | `INTEGER` |
| `double` | `real` | `double precision`, or `numeric` (read as text and parsed) | `REAL` |
| `num` | `number` | any numeric type | `INTEGER` or `REAL` |
| `String` | `text` | `text`, `varchar` | `TEXT` |
| `bool` | `boolean` | `boolean` | `INTEGER`, bound as `1`/`0` |
| `DateTime` | `dateTime` | `timestamptz`, or `timestamp` (holding UTC) | `TEXT`, stored as UTC ISO-8601 |
| `Uint8List` | `bytes` | `bytea` | `BLOB` |
| an enum | `enumeration` (by `.name`) | `text` | `TEXT` |

- Each accessor has an `OrNull` variant for nullable fields. It reads a null
  value or a missing column as `null`.
- A non-nullable accessor throws a `MappingException` for a null value or a
  missing column. So does any accessor given a value it cannot convert. The
  message names the entity, the field, the column and the type of the value,
  but never the value itself.
- SQLite needs version 3.35 or newer for `RETURNING`, which `insert`, `update`
  and `returning: true` use.
- `SqliteDriver` binds a `DateTime` as UTC ISO-8601 text with six fractional
  digits, such as `2024-05-06T07:08:09.010000Z`. The value reads back in
  UTC, and for years 0 to 9999 these texts sort and compare in time order,
  so `ORDER BY` and `Query.where(..., '>', dateTime)` work on them. Text
  without an offset, such as SQLite's `CURRENT_TIMESTAMP` or a date on its
  own, is read as UTC, but it has another shape, so do not compare or sort it
  together with values the driver bound.
- `PostgresDriver` binds a `DateTime` as the same instant in UTC. A
  `timestamptz` or `timestamp` column therefore round-trips the instant of a
  local `DateTime` too. For a `date` column, pass
  `DateTime.utc(year, month, day)`, which is also how the driver reads it.
- On Postgres, store enums in `text` columns. The driver returns values of a
  Postgres `ENUM` type undecoded, so they cannot be mapped.

## Using it with Ratel

Ratel has no database layer. The server's startup and shutdown hooks open and
close the driver, and `Bindings` hands repositories to controllers:

```dart
import 'package:ratel/ratel.dart';
import 'package:ratel_orm/postgres.dart';
import 'package:ratel_orm/ratel_orm.dart';

class AppBindings extends Bindings {
  AppBindings(this.driver);

  final RatelDriver driver;

  @override
  void dependencies() {
    Injector().put<UserRepository>(() => UserRepository(driver));
  }
}

Future<void> main() async {
  final driver = PostgresDriver.fromEnv();
  final server = RatelServer(
    port: 8080,
    bindings: AppBindings(driver),
    onStartup: driver.open,
    onShutdown: driver.close,
  );
  await server.startServer();
}
```

## The driver contract

`RatelDriver` is a base class that drivers extend, so members can be added
without breaking them. Every driver follows these rules. The conformance
suite in this repository checks them against `SqliteDriver` and `FakeDriver`,
and its basic checks also run against a live `PostgresDriver`:

- Parameters use named placeholders (`@name`) that match the keys of the
  `parameters` map. With no parameters, the SQL runs verbatim.
- Accepted parameter values are `null`, `bool`, `int`, `double`, `String`,
  `DateTime` and `Uint8List` (bytes). `SqliteDriver` binds any `List<int>`
  as bytes. `PostgresDriver` binds a `List<int>` that is not a `Uint8List`
  as an array, as in `WHERE id = ANY(@ids)`, so pass bytes for `bytea` as a
  `Uint8List`.
- Native engine errors surface as a `DatabaseException`. On SQLite, that
  includes a parameter value it cannot bind.
- `open` is idempotent. `close` releases every resource.
- `transaction` runs its action on one connection. It commits when the action
  completes and rolls back when the action throws. Queries sent through the
  driver from inside the action run on that connection too.
- `dialect` tells the query builder and the repository how to quote
  identifiers and render `LIMIT`, `OFFSET` and `RETURNING`.

## Testing

`package:ratel_orm/testing.dart` provides `FakeDriver`, an in-memory driver.
Queue results with `enqueue` or `enqueueRows`, inspect the last call through
`lastSql` and `lastParameters`, and force a failure with `errorToThrow`. It
does not import `package:test`, so it is safe to use outside tests.

Under plain `dart test` no manifest is generated. Build the entity definition
by hand, the way the CLI would generate it, and install it once per test
file. `toRow` maps each field name (not the column name) to its value, and
turns an enum into its `.name`:

```dart
import 'package:ratel_orm/runtime.dart';
import 'package:ratel_orm/testing.dart';
import 'package:test/test.dart';

abstract final class UserDefinition {
  static const value = EntityDefinition<User>(
    name: 'User',
    table: 'users',
    columns: [
      ColumnDefinition(field: 'id', isId: true),
      ColumnDefinition(field: 'email', name: 'email_address'),
      ColumnDefinition(field: 'role'),
      ColumnDefinition(field: 'createdAt'),
      ColumnDefinition(field: 'lastLoginAt'),
    ],
    fromRow: _fromRow,
    toRow: _toRow,
  );

  static User _fromRow(EntityRow row) => User(
        id: row.integerOrNull('id'),
        email: row.text('email'),
        role: row.enumeration('role', Role.values),
        createdAt: row.dateTime('createdAt'),
        lastLoginAt: row.dateTimeOrNull('lastLoginAt'),
      );

  static Map<String, Object?> _toRow(User user) => {
        'id': user.id,
        'email': user.email,
        'role': user.role.name,
        'createdAt': user.createdAt,
        'lastLoginAt': user.lastLoginAt,
      };
}

void main() {
  RatelOrmRuntime.install(
    const EntityManifest(entities: [UserDefinition.value]),
  );

  test('finds a user', () async {
    final driver = FakeDriver()
      ..enqueueRows([
        {
          'id': 1,
          'email_address': 'ada@example.com',
          'role': 'admin',
          'created_at': '2024-05-06T07:08:09.000Z',
          'last_login_at': null,
        },
      ]);
    final user = await UserRepository(driver).findById(1);
    expect(user?.isAdmin, isTrue);
  });
}
```

Test files run in separate isolates, so each file installs the manifest
itself. An isolate accepts only one manifest, so do not install a hand-built
manifest where the CLI has already installed one.

## Status

Early development (`0.2.0-dev`). The API may change before `1.0`.
