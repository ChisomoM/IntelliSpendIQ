import 'package:equatable/equatable.dart';
import 'package:intellispendiq/domain/models/enums.dart';

/// A named target the user is setting money aside for — a laptop, a
/// deposit, a trip. A contribution really moves money, via a [Transfer],
/// out of the source account and into this goal's own hidden account
/// (see [accountId]) — it's not just an earmark on paper.
class SavingsGoal extends Equatable {
  const SavingsGoal({
    required this.id,
    required this.name,
    required this.targetMinor,
    required this.status,
    this.targetDate,
    this.defaultAccountId,
    this.accountId,
  });

  final String id;
  final String name;

  /// The amount being saved toward, in ngwee.
  final int targetMinor;
  final DateTime? targetDate;

  /// Account a contribution sheet defaults to picking from, when set.
  final String? defaultAccountId;
  final GoalStatus status;

  /// The hidden account that actually holds this goal's saved money.
  /// Nullable only for goals created before this existed —
  /// `SavingsGoalRepository` creates one lazily on first use for those.
  final String? accountId;

  @override
  List<Object?> get props => [
    id,
    name,
    targetMinor,
    targetDate,
    defaultAccountId,
    status,
    accountId,
  ];
}
