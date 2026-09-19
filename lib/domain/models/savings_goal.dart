import 'package:equatable/equatable.dart';
import 'package:intellispendiq/domain/models/enums.dart';

/// A named target the user is setting money aside for — a laptop, a
/// deposit, a trip. Money "in" a goal never physically leaves the real
/// account it was contributed from; a goal only earmarks part of that
/// account's balance (see [SavingsGoalEntry]), the same way an envelope
/// budget earmarks part of a period's income without moving it anywhere.
class SavingsGoal extends Equatable {
  const SavingsGoal({
    required this.id,
    required this.name,
    required this.targetMinor,
    required this.status,
    this.targetDate,
    this.defaultAccountId,
  });

  final String id;
  final String name;

  /// The amount being saved toward, in ngwee.
  final int targetMinor;
  final DateTime? targetDate;

  /// Account a contribution sheet defaults to picking from, when set.
  final String? defaultAccountId;
  final GoalStatus status;

  @override
  List<Object?> get props => [
    id,
    name,
    targetMinor,
    targetDate,
    defaultAccountId,
    status,
  ];
}
