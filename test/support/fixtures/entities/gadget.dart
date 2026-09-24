import 'dart:typed_data';

import 'package:ratel_orm/ratel_orm.dart';

import 'gadget_kind.dart';

@Entity(table: 'gadgets')
final class Gadget {
  const Gadget({
    this.id,
    required this.name,
    required this.kind,
    required this.active,
    required this.price,
    required this.createdAt,
    this.note,
    this.payload,
    this.selected = false,
  });

  @Id()
  final int? id;
  @Column(name: 'display_name')
  final String name;
  final GadgetKind kind;
  final bool active;
  final double price;
  final DateTime createdAt;
  final String? note;
  final Uint8List? payload;
  @Transient()
  final bool selected;
}
