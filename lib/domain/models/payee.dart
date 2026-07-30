import 'package:equatable/equatable.dart';

/// A structured payee, selectable on the expense form as an
/// alternative to the free-text merchant field.
class Payee extends Equatable {
  const Payee({required this.id, required this.name});

  final String id;
  final String name;

  @override
  List<Object?> get props => [id, name];
}
