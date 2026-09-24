import 'package:ratel_orm/ratel_orm.dart';

@Entity(table: 'counters')
final class Counter {
  const Counter({this.id});

  @Id()
  final int? id;
}
