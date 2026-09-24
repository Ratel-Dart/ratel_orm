import 'dart:io';

import 'package:ratel_orm/ratel_orm.dart';
import 'package:ratel_orm/sqlite.dart';
import 'package:ratel_orm_example/entities/note.dart';
import 'package:ratel_orm_example/repositories/note_repository.dart';
import 'package:ratel_orm_example/schema/note_schema.dart';

Future<void> main() async {
  final driver = SqliteDriver.memory();
  await driver.open();
  try {
    await Migrator(driver).migrate([NoteSchema.migrationFor(driver)]);
    final notes = NoteRepository(driver);
    final first = await notes.insert(
      Note(body: 'Hello from ratel_orm', createdAt: DateTime.utc(2026, 1, 1)),
    );
    await notes.insert(
      Note(body: 'Pinned', createdAt: DateTime.utc(2026, 1, 2), pinned: true),
    );
    final all = await notes.findAll();
    final pinned = await notes.pinned();
    stdout.writeln(
        'inserted ${first.id}, ${all.length} notes, ${pinned.length} pinned');
  } finally {
    await driver.close();
  }
}
