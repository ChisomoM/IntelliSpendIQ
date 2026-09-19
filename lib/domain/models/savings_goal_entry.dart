import 'package:equatable/equatable.dart';
import 'package:intellispendiq/domain/models/enums.dart';

/// One movement of money into or out of a [SavingsGoal]'s earmark.
/// Never a [Transaction] itself — a contribution and a plain withdrawal
/// carry no spend/income meaning, exactly like a [Transfer] — but a
/// withdrawal that funded an actual purchase carries
/// [linkedTransactionId] pointing at the expense it backed.
class SavingsGoalEntry extends Equatable {
  const SavingsGoalEntry({
    required this.id,
    required this.goalId,
    required this.accountId,
    required this.amountMinor,
    required this.kind,
    required this.transactedAt,
    this.note,
    this.linkedTransactionId,
  });

  final String id;
  final String goalId;

  /// The real account the money was earmarked from (contribution) or
  /// released back to (withdrawal).
  final String accountId;

  /// Always positive; [kind] carries the direction.
  final int amountMinor;
  final GoalEntryKind kind;
  final DateTime transactedAt;
  final String? note;

  /// Set only when this withdrawal is the goal-funded portion of a real
  /// purchase — the [Transaction] recording that purchase.
  final String? linkedTransactionId;

  @override
  List<Object?> get props => [
    id,
    goalId,
    accountId,
    amountMinor,
    kind,
    transactedAt,
    note,
    linkedTransactionId,
  ];
}
