import 'package:equatable/equatable.dart';
import 'package:intellispendiq/domain/models/enums.dart';

/// One movement of money into or out of a [SavingsGoal]'s own hidden
/// account. Never a [Transaction] itself — a contribution and a plain
/// withdrawal carry no spend/income meaning, exactly like a [Transfer]
/// (and are in fact backed by one, via [linkedTransferId]) — but a
/// withdrawal that funded an actual purchase carries
/// [linkedTransactionId] pointing at the expense it backed instead.
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
    this.linkedTransferId,
  });

  final String id;
  final String goalId;

  /// The real account the money was transferred from (contribution) or
  /// back to (withdrawal).
  final String accountId;

  /// Always positive; [kind] carries the direction.
  final int amountMinor;
  final GoalEntryKind kind;
  final DateTime transactedAt;
  final String? note;

  /// Set only when this withdrawal is the goal-funded portion of a real
  /// purchase — the [Transaction] recording that purchase.
  final String? linkedTransactionId;

  /// The real [Transfer] that moved this contribution's or plain
  /// withdrawal's money between [accountId] and the goal's hidden
  /// account. Null for the goal-funded portion of a purchase — that leg
  /// moves no money of its own, [linkedTransactionId] already covers it.
  final String? linkedTransferId;

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
    linkedTransferId,
  ];
}
