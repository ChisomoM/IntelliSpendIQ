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

/// One local calendar day of the Activity feed, with its net movement.
///
/// Grouping happens here rather than in the list builder so the day
/// header and its total can never disagree about which entries the day
/// contains.
class ActivityDayGroup {
  const ActivityDayGroup({
    required this.day,
    required this.entries,
    required this.netMinor,
  });

  /// Local midnight of the day these entries fall on.
  final DateTime day;
  final List<ActivityEntry> entries;

  /// Money in minus money out for the day. Transfers are excluded —
  /// moving money between your own accounts changes neither, and
  /// counting a transfer here would make an ordinary Tuesday look like
  /// a windfall or a disaster.
  final int netMinor;
}
