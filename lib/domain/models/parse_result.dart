import 'package:equatable/equatable.dart';
import 'package:intellispendiq/domain/models/transaction_draft.dart';

/// Outcome of running a parser over a raw capture.
///
/// Success carries a [TransactionDraft]; failure carries a reason and the
/// raw capture stays stored with `parse_status = failed` so it surfaces
/// in the Review Inbox — a capture is never silently dropped.
sealed class ParseResult extends Equatable {
  const ParseResult();

  const factory ParseResult.success(TransactionDraft draft) = ParseSuccess;

  const factory ParseResult.failure(String reason) = ParseFailure;
}

class ParseSuccess extends ParseResult {
  const ParseSuccess(this.draft);

  final TransactionDraft draft;

  @override
  List<Object?> get props => [draft];
}

class ParseFailure extends ParseResult {
  const ParseFailure(this.reason);

  final String reason;

  @override
  List<Object?> get props => [reason];
}
