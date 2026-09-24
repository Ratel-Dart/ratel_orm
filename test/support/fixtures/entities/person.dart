import 'package:ratel_orm/ratel_orm.dart';

@Entity()
final class Person {
  const Person({required this.id, required this.name, required this.age});

  @Id()
  final int id;
  final String name;
  final int age;
}
