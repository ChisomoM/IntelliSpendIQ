import 'package:equatable/equatable.dart';

/// A monthly spending limit for one category.
class Budget extends Equatable {
  const Budget({
    required this.id,
    required this.categoryId,
    required this.period,
    required this.amountMinor,
    this.carryOver = true,
  });

  final String id;
  final String categoryId;

  /// Month key, `YYYY-MM`.
  final String period;

  /// Monthly limit in ngwee.
  final int amountMinor;

  /// Whether next month defaults from this one.
  final bool carryOver;

  @override
  List<Object?> get props => [id, categoryId, period, amountMinor, carryOver];
}
