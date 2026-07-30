import 'package:equatable/equatable.dart';

/// A tag attachable to any number of transactions, for cross-cutting
/// grouping beyond category (e.g. "Work trip", "Tax deductible").
class Label extends Equatable {
  const Label({required this.id, required this.name, this.color});

  final String id;
  final String name;
  final String? color;

  @override
  List<Object?> get props => [id, name, color];
}
