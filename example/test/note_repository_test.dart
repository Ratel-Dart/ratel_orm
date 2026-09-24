import 'dart:io';

import 'package:ratel_orm/postgres.dart';
import 'package:ratel_orm/ratel_orm.dart';
import 'package:ratel_orm/sqlite.dart';
import 'package:ratel_orm_example/entities/note.dart';
import 'package:ratel_orm_example/repositories/note_repository.dart';
import 'package:ratel_orm_example/schema/note_schema.dart';
import 'package:test/test.dart';

void main() {
  late RatelDriver driver;
  late NoteRepository notes;

  setUp(() async {
    driver = Platform.environment['DB_HOST'] == null
        ? SqliteDriver.memory()
        : PostgresDriver.fromEnv();
    await driver.open();
    await driver.query('DROP TABLE IF EXISTS notes');
    await driver.query('DROP TABLE IF EXISTS ratel_migrations');
    await Migrator(driver).migrate([NoteSchema.migrationFor(driver)]);
    notes = NoteRepository(driver);
  });

  tearDown(() async {
    await driver.query('DROP TABLE IF EXISTS notes');
    await driver.query('DROP TABLE IF EXISTS ratel_migrations');
    await driver.close();
  });

  test('inserts a note and reads it back by its generated id', () async {
    final createdAt = DateTime.utc(2026, 3, 4, 5, 6, 7);
    final saved = await notes.insert(Note(body: 'draft', createdAt: createdAt));

    expect(saved.id, isNotNull);
    final found = await notes.findById(saved.id!);
    expect(found!.body, 'draft');
    expect(found.createdAt.isAtSameMomentAs(createdAt), isTrue);
    expect(found.pinned, isFalse);
  });

  test('updates, queries and deletes notes', () async {
    final saved = await notes.insert(
      Note(body: 'first', createdAt: DateTime.utc(2026, 1, 1)),
    );
    final updated = await notes.update(
      Note(
        id: saved.id,
        body: 'first, edited',
        createdAt: saved.createdAt,
        pinned: true,
      ),
    );

    expect(updated!.body, 'first, edited');
    expect((await notes.pinned()).single.id, saved.id);
    expect(await notes.deleteById(saved.id!), isTrue);
    expect(await notes.findById(saved.id!), isNull);
    expect(await notes.findAll(), isEmpty);
  });
}
