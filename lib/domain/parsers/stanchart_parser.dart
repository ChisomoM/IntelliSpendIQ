import 'package:intellispendiq/domain/models/capture_input.dart';
import 'package:intellispendiq/domain/models/enums.dart';
import 'package:intellispendiq/domain/models/parse_result.dart';
import 'package:intellispendiq/domain/models/transaction_draft.dart';
import 'package:intellispendiq/domain/parsers/parser_provider.dart';
import 'package:intellispendiq/domain/parsers/parsing_utils.dart';

/// Deterministic parser for Standard Chartered Zambia alert SMS.
///
/// Only the outbound-transfer template is known so far (plan §8.5);
/// anything else fails parsing and lands in the Review Inbox, which is
/// exactly where we want unknown StanChart formats until more samples
/// are collected.
class StanChartParser extends ParserProvider {
  static const providerKey = 'stan_chart';

  @override
  String get key => providerKey;

  @override
  String get displayName => 'Standard Chartered';

  @override
  Set<String> get senderIds => const {'stanchartzm', '78262427896'};

  static final _txnTo = RegExp(
    r'transaction of\s+' +
        ParsingUtils.currencyAmount +
        r'\s+to\s+(.+?)\s+has been processed successfully,?\s*ref\.?\s*([A-Z0-9]+)',
    caseSensitive: false,
  );

  @override
  ParseResult parse(CaptureInput capture) {
    final body = capture.body.trim();
    final match = _txnTo.firstMatch(body);
    if (match == null) {
      return const ParseResult.failure(
        'No StanChart rule family matched this message '
        '(only outbound transfers are supported so far)',
      );
    }
    final amount = ParsingUtils.amountMinorFrom(match, 1);
    if (amount == null) {
      return const ParseResult.failure('Could not parse StanChart amount');
    }
    return ParseResult.success(
      TransactionDraft(
        amountMinor: amount,
        direction: TxDirection.debit,
        source: capture.channel == CaptureChannel.notification
            ? TxSource.notification
            : TxSource.sms,
        transactedAt: capture.receivedAt,
        merchant: match.group(2)!.trim(),
        paymentMethod: 'bank',
        externalRef: match.group(3),
        confidence: 1,
        typeHint: 'txn_to',
        metadata: const {'family': 'txn_to'},
      ),
    );
  }
}
