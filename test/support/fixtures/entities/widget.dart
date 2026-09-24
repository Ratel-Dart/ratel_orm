import 'package:ratel_orm/ratel_orm.dart';

@Entity(table: 'widgets')
final class Widget {
  const Widget({required this.id, required this.name});

  @Id()
  final int id;
  final String name;
}
