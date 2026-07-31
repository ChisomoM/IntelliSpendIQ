import 'package:intellispendiq/domain/models/transaction.dart';
import 'package:intellispendiq/domain/models/transfer.dart';

/// One row in the Activity feed — either an ordinary transaction or a
/// transfer between two of the user's own accounts. Merged into a
/// single, date-sorted list so a linked transfer still shows up in
/// history instead of disappearing once its two original legs are
/// soft-deleted.
sealed class ActivityEntry {
  const ActivityEntry();

  DateTime get transactedAt;
}

class TransactionEntry extends ActivityEntry {
  const TransactionEntry(this.transaction);

  final Transaction transaction;

  @override
  DateTime get transactedAt => transaction.transactedAt;
}

class TransferEntry extends ActivityEntry {
  const TransferEntry(this.transfer);

  final Transfer transfer;

  @override
  DateTime get transactedAt => transfer.transactedAt;
}
