import 'package:ratel_orm/ratel_orm.dart';

@Entity(table: 'ratel_repo_widgets')
final class LabeledWidget {
  const LabeledWidget({required this.id, required this.label});

  @Id()
  final int id;
  final String label;
}
