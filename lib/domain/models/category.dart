import 'package:equatable/equatable.dart';

/// A spending category.
class Category extends Equatable {
  const Category({
    required this.id,
    required this.name,
    this.icon,
    this.color,
    this.parentId,
    this.isSystem = false,
    this.sortOrder = 0,
  });

  final String id;
  final String name;
  final String? icon;
  final String? color;
  final String? parentId;

  /// Seeded on first launch. Still editable — this only marks origin.
  final bool isSystem;
  final int sortOrder;

  /// Icon and name together, the form every list shows. Lived in three
  /// separate widgets before this.
  String get displayName => icon == null ? name : '$icon $name';

  @override
  List<Object?> get props => [
    id,
    name,
    icon,
    color,
    parentId,
    isSystem,
    sortOrder,
  ];
}
