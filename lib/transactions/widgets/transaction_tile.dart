import 'package:flutter/material.dart';
import 'package:intellispendiq/design/design.dart';
import 'package:intellispendiq/domain/models/enums.dart';
import 'package:intellispendiq/domain/models/transaction.dart';
import 'package:intellispendiq/domain/models/transfer.dart';
import 'package:intellispendiq/transactions/view/view.dart';
import 'package:intellispendiq/transactions/widgets/raw_source_sheet.dart';
import 'package:intl/intl.dart';

/// One entry in the ledger.
///
/// Confidence is marked per the brand guide: a cleanly-parsed entry
/// carries no badge at all, and an entry the app is unsure of marks
/// only the uncertain part — never the whole row, which would read as
/// "this is wrong" rather than "this one value is a guess". The row
/// still counts toward the balance either way.
class TransactionTile extends StatelessWidget {
  const TransactionTile({
    required this.transaction,
    this.categoryIcon,
    this.showSource = true,
    super.key,
  });

  final Transaction transaction;

  /// Icon key from the entry's category, resolved by the caller — a
  /// [Transaction] carries only the category id.
  final String? categoryIcon;

  /// Whether to show the capture-source chip. Off in compact previews
  /// where the extra mark is noise.
  final bool showSource;

  static final _timeFormat = DateFormat('HH:mm');

  static CaptureSource _sourceOf(TxSource source) => switch (source) {
    TxSource.sms || TxSource.notification => CaptureSource.sms,
    TxSource.voice => CaptureSource.voice,
    TxSource.manual => CaptureSource.manual,
  };

  /// The one word that names an unresolved state, so colour is never
  /// the only signal. Null for a clean entry — silence is the signal.
  static String? _statusWord(TxStatus status) => switch (status) {
    TxStatus.confirmed => null,
    TxStatus.needsReview => 'needs a detail',
    TxStatus.duplicateSuspect => 'possible duplicate',
    TxStatus.planned => 'planned',
  };

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final time = _timeFormat.format(transaction.transactedAt.toLocal());
    final statusWord = _statusWord(transaction.status);
    final hasMerchant = transaction.merchant?.isNotEmpty ?? false;

    return AppListRow(
      leading: CategoryAvatar(iconKey: categoryIcon),
      title: Row(
        children: [
          Flexible(
            // A parsed entry with no merchant is a gap the app is
            // showing, not a fact it read — so it is marked rather
            // than presented as though it came through cleanly.
            child: hasMerchant
                ? Text(
                    transaction.merchant!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  )
                : UncertainText('Unknown', style: AppTypography.rowTitle()),
          ),
          if (transaction.receiptPath != null) ...[
            const SizedBox(width: 6),
            AppIcon(
              AppIcons.scanReceipt,
              size: 14,
              color: colors.onSurfaceVariant,
            ),
          ],
        ],
      ),
      subtitle: Row(
        children: [
          if (showSource) ...[
            SourceChip(_sourceOf(transaction.source)),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: statusWord == null
                ? Text(time, maxLines: 1, overflow: TextOverflow.ellipsis)
                : UncertainText('$time · $statusWord'),
          ),
        ],
      ),
      trailing: MoneyText.signed(
        transaction.amountMinor,
        isInflow: transaction.direction == TxDirection.credit,
      ),
      onTap: () => Navigator.of(
        context,
      ).push<void>(TransactionEntryPage.route(existing: transaction)),
      // The raw text stays reachable for anything the app read from a
      // message, which the guide requires and nothing offered before.
      onLongPress: transaction.rawCaptureId == null
          ? null
          : () => RawSourceSheet.show(
              context,
              rawCaptureId: transaction.rawCaptureId!,
            ),
    );
  }
}

/// Renders a confirmed [Transfer] — money moved between two of the
/// user's own accounts — as a neutral row, distinct from a debit or
/// credit transaction. Not dismissible: unlinking a transfer back into
/// two separate transactions isn't supported.
class TransferTile extends StatelessWidget {
  const TransferTile({
    required this.transfer,
    required this.fromAccountName,
    required this.toAccountName,
    super.key,
  });

  final Transfer transfer;
  final String fromAccountName;
  final String toAccountName;

  static final _timeFormat = DateFormat('HH:mm');

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return AppListRow(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: colors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(Radii.card),
        ),
        alignment: Alignment.center,
        child: AppIcon(
          AppIcons.transfer,
          size: 20,
          color: colors.onSurfaceVariant,
        ),
      ),
      title: Text('$fromAccountName → $toAccountName'),
      // Named in words, not just styled neutrally: a transfer moves
      // money without spending it, and nothing else on the row says so.
      subtitle: Text(
        '${_timeFormat.format(transfer.transactedAt.toLocal())} · transfer',
      ),
      trailing: MoneyText(transfer.amountMinor, color: colors.onSurfaceVariant),
    );
  }
}

class NoTransactionsYet extends StatelessWidget {
  const NoTransactionsYet({this.onAddTransaction, super.key});

  final VoidCallback? onAddTransaction;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: AppIcons.emptyActivity,
      title: 'No entries yet',
      message: 'Bank and mobile money alerts are captured on their own '
          'once SMS access is granted. You can also add one by hand.',
      actionLabel: onAddTransaction == null ? null : 'Add an entry',
      onAction: onAddTransaction,
    );
  }
}
