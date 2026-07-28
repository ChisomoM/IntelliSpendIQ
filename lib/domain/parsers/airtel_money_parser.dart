import 'package:intellispendiq/domain/models/capture_input.dart';
import 'package:intellispendiq/domain/models/enums.dart';
import 'package:intellispendiq/domain/models/parse_result.dart';
import 'package:intellispendiq/domain/models/transaction_draft.dart';
import 'package:intellispendiq/domain/parsers/parser_provider.dart';
import 'package:intellispendiq/domain/parsers/parsing_utils.dart';

/// Deterministic parser for Airtel Money ZM alert SMS.
///
/// Rule families (plan §8.4): payment_till, paid_to, withdrawn,
/// money_sent, received_k, money_received.
class AirtelMoneyParser extends ParserProvider {
  static const providerKey = 'airtel_money';

  @override
  String get key => providerKey;

  @override
  String get displayName => 'Airtel Money';

  @override
  Set<String> get senderIds => const {'airtelmoney', '24783566639'};

  static final _paymentTill = RegExp(
    r'^Payment of\s+' +
        ParsingUtils.currencyAmount +
        r'\s+Till Number\s+(.+?)\.\s*Airtel Money bal',
  );

  static final _paidTo = RegExp(
    r'^PAID\s+' +
        ParsingUtils.currencyAmount +
        r'\s+to\s+(.+?)\s+Charge\s+' +
        ParsingUtils.currencyAmount,
  );

  static final _paidToNoCharge = RegExp(
    r'^PAID\s+' +
        ParsingUtils.currencyAmount +
        r'\s+to\s+(.+?)(?:[.,]|\s+TID|$)',
  );

  static final _withdrawn = RegExp(
    r'^You have withdrawn\s+' +
        ParsingUtils.currencyAmount +
        r'\s+from\s+(.+?)\.\s*Bal',
  );

  static final _moneySent = RegExp(
    r'^Money sent to\s+(.+?)\s+on\s+([0-9]+)\s*\.\s*Amount\s+' +
        ParsingUtils.currencyAmount,
  );

  static final _received = RegExp(
    r'^You have received\s+' +
        ParsingUtils.currencyAmount +
        r'\s+from\s+(.+?)\.\s*(?:Txn|TID)',
  );

  static final _moneyReceived = RegExp(
    r'^Money received\s+' +
        ParsingUtils.currencyAmount +
        r'\s+from\s+(.+?)\.\s',
  );

  static final _reason = RegExp(r'Reason:\s*([^.]+)');

  @override
  ParseResult parse(CaptureInput capture) {
    final body = ParsingUtils.stripTrailingLinks(capture.body.trim());

    final draft =
        _paymentTillDraft(body, capture) ??
        _paidToDraft(body, capture) ??
        _withdrawnDraft(body, capture) ??
        _moneySentDraft(body, capture) ??
        _receivedDraft(body, capture) ??
        _moneyReceivedDraft(body, capture);

    if (draft == null) {
      return const ParseResult.failure(
        'No Airtel Money rule family matched this message',
      );
    }
    return ParseResult.success(draft);
  }

  TransactionDraft? _paymentTillDraft(String body, CaptureInput capture) {
    final match = _paymentTill.firstMatch(body);
    if (match == null) return null;
    final amount = ParsingUtils.amountMinorFrom(match, 1);
    if (amount == null) return null;
    final tillSection = match.group(2)!.trim();
    final (till, merchant) = ParsingUtils.splitLeadingNumber(tillSection);
    return _draft(
      capture: capture,
      amountMinor: amount,
      direction: TxDirection.debit,
      merchant: merchant,
      typeHint: 'payment_till',
      metadata: {
        if (till != null)
          'till': till
        else
          'till_token': tillSection.split(' ').first,
      },
    );
  }

  TransactionDraft? _paidToDraft(String body, CaptureInput capture) {
    var match = _paidTo.firstMatch(body);
    int? feeMinor;
    if (match != null) {
      final charge = ParsingUtils.amountMinorFrom(match, 3);
      if (charge != null && charge > 0) feeMinor = charge;
    } else {
      match = _paidToNoCharge.firstMatch(body);
    }
    if (match == null) return null;
    final amount = ParsingUtils.amountMinorFrom(match, 1);
    if (amount == null) return null;
    return _draft(
      capture: capture,
      amountMinor: amount,
      direction: TxDirection.debit,
      merchant: match.group(2)!.trim(),
      typeHint: 'paid_to',
      transactedAt: ParsingUtils.embeddedDateTime(body),
      feeMinor: feeMinor,
    );
  }

  TransactionDraft? _withdrawnDraft(String body, CaptureInput capture) {
    final match = _withdrawn.firstMatch(body);
    if (match == null) return null;
    final amount = ParsingUtils.amountMinorFrom(match, 1);
    if (amount == null) return null;
    final (agentNumber, agentName) = ParsingUtils.splitLeadingNumber(
      match.group(2)!,
    );
    return _draft(
      capture: capture,
      amountMinor: amount,
      direction: TxDirection.debit,
      merchant: agentName,
      typeHint: 'withdrawal',
      metadata: {'agent_number': ?agentNumber},
    );
  }

  TransactionDraft? _moneySentDraft(String body, CaptureInput capture) {
    final match = _moneySent.firstMatch(body);
    if (match == null) return null;
    final amount = ParsingUtils.amountMinorFrom(match, 3);
    if (amount == null) return null;
    return _draft(
      capture: capture,
      amountMinor: amount,
      direction: TxDirection.debit,
      merchant: match.group(1)!.trim(),
      typeHint: 'send',
      metadata: {'recipient_phone': match.group(2)},
    );
  }

  TransactionDraft? _receivedDraft(String body, CaptureInput capture) {
    final match = _received.firstMatch(body);
    if (match == null) return null;
    final amount = ParsingUtils.amountMinorFrom(match, 1);
    if (amount == null) return null;
    final reason = _reason.firstMatch(body)?.group(1)?.trim();
    return _draft(
      capture: capture,
      amountMinor: amount,
      direction: TxDirection.credit,
      merchant: match.group(2)!.trim(),
      description: reason,
      typeHint: 'receive',
    );
  }

  TransactionDraft? _moneyReceivedDraft(String body, CaptureInput capture) {
    final match = _moneyReceived.firstMatch(body);
    if (match == null) return null;
    final amount = ParsingUtils.amountMinorFrom(match, 1);
    if (amount == null) return null;
    final (senderNumber, senderName) = ParsingUtils.splitLeadingNumber(
      match.group(2)!,
    );
    return _draft(
      capture: capture,
      amountMinor: amount,
      direction: TxDirection.credit,
      merchant: senderName,
      typeHint: 'receive',
      metadata: {'sender_number': ?senderNumber},
    );
  }

  TransactionDraft _draft({
    required CaptureInput capture,
    required int amountMinor,
    required TxDirection direction,
    required String typeHint,
    String? merchant,
    String? description,
    DateTime? transactedAt,
    int? feeMinor,
    Map<String, Object?> metadata = const {},
  }) {
    return TransactionDraft(
      amountMinor: amountMinor,
      direction: direction,
      source: capture.channel == CaptureChannel.notification
          ? TxSource.notification
          : TxSource.sms,
      transactedAt: transactedAt ?? capture.receivedAt,
      merchant: merchant,
      description: description,
      paymentMethod: 'mobile_money',
      externalRef: ParsingUtils.tid(capture.body),
      confidence: 1,
      balanceMinor: ParsingUtils.balanceMinor(capture.body),
      typeHint: typeHint,
      feeMinor: feeMinor,
      metadata: {'family': typeHint, ...metadata},
    );
  }
}
