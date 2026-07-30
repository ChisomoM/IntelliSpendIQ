import 'package:equatable/equatable.dart';
import 'package:intellispendiq/core/money.dart';
import 'package:intellispendiq/domain/models/enums.dart';

/// Something the chat assistant wants to do, surfaced as a confirmation
/// card rather than written straight away.
///
/// The assistant can analyze data freely — that's read-only — but
/// every write it proposes stops here until a human taps confirm. The
/// [toolUseId] is what lets `FinanceChatService` resume the paused
/// tool-use turn once that decision is made.
sealed class ProposedAction extends Equatable {
  const ProposedAction({required this.toolUseId});

  final String toolUseId;

  /// Confirmation-card headline.
  String get title;

  /// Confirmation-card supporting line.
  String get subtitle;
}

class ProposedTransaction extends ProposedAction {
  const ProposedTransaction({
    required super.toolUseId,
    required this.amountMinor,
    required this.direction,
    required this.accountId,
    this.merchant,
    this.description,
    this.categoryId,
    this.categoryName,
  });

  final int amountMinor;
  final TxDirection direction;

  /// Resolved default account this will be recorded against.
  final String accountId;
  final String? merchant;
  final String? description;

  /// Null when the assistant's guess didn't match a known category —
  /// saved uncategorized rather than blocking on it, same as manual
  /// entry and SMS capture.
  final String? categoryId;
  final String? categoryName;

  @override
  String get title {
    final sign = direction == TxDirection.debit ? '-' : '+';
    final who = merchant?.isNotEmpty ?? false ? ' · $merchant' : '';
    return '$sign${Money.format(amountMinor)}$who';
  }

  @override
  String get subtitle => categoryName ?? 'Uncategorized';

  @override
  List<Object?> get props => [
    toolUseId,
    amountMinor,
    direction,
    accountId,
    merchant,
    description,
    categoryId,
    categoryName,
  ];
}

class ProposedBudget extends ProposedAction {
  const ProposedBudget({
    required super.toolUseId,
    required this.categoryId,
    required this.categoryName,
    required this.amountMinor,
  });

  final String categoryId;
  final String categoryName;

  /// A standing monthly limit — categories are the budget line now,
  /// not a per-period row.
  final int amountMinor;

  @override
  String get title => '$categoryName: ${Money.format(amountMinor)} / month';

  @override
  String get subtitle => 'Monthly budget';

  @override
  List<Object?> get props => [toolUseId, categoryId, categoryName, amountMinor];
}
