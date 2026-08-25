import 'package:intellispendiq/domain/models/capture_input.dart';
import 'package:intellispendiq/domain/models/enums.dart';
import 'package:intellispendiq/domain/models/parse_result.dart';
import 'package:intellispendiq/domain/models/transaction_draft.dart';
import 'package:intellispendiq/domain/parsers/parser_provider.dart';
import 'package:intellispendiq/domain/parsers/parsing_utils.dart';

/// Deterministic parser for MTN MoMo Zambia alert SMS.
///
/// Known families so far: merchant/NFS `payment`, and P2P `send`.
/// Anything else fails parsing and lands in the Review Inbox until
/// more samples are collected.
class MtnMoMoParser extends ParserProvider {
  static const providerKey = 'mtn_momo';

  @override
  String get key => providerKey;

  @override
  String get displayName => 'MTN MoMo';

  /// `24783566639` is also claimed by Airtel Money — the registry tries
  /// every provider that owns a sender until one parses the body.
  @override
  Set<String> get senderIds => const {'6666', '24783566639'};

  static const _dateTime =
      r'([0-9]{4})-([0-9]{2})-([0-9]{2})\s+([0-9]{2}):([0-9]{2}):([0-9]{2})';

  static final _payment = RegExp(
    "^(?:Y['\u2019]?ello\\.\\s*)?Payment of\\s+" +
        ParsingUtils.currencyAmount +
        r'\s+to\s+(.+?)\s+successful at\s+' +
        _dateTime,
    caseSensitive: false,
  );

  static final _transferred = RegExp(
    r'^You have transferred\s+' +
        ParsingUtils.amountThenZmw +
        r'\s+to\s+(.+?)\s+\(([0-9]+)\)\s+from your mobile money account\s+'
            r'([0-9]+)\s+at\s+' +
        _dateTime,
    caseSensitive: false,
  );

  static final _txnId = RegExp(
    r'Financial Transaction ID:\s*([0-9]+)',
    caseSensitive: false,
  );

  static final _paymentNote = RegExp(
    r'Message:\s*-?\s*(.+?)\.\s*Your new balance',
    caseSensitive: false,
  );

  @override
  ParseResult parse(CaptureInput capture) {
    final body = ParsingUtils.stripTrailingLinks(capture.body.trim());

    final draft = _paymentDraft(body, capture) ?? _sendDraft(body, capture);

    if (draft == null) {
      return const ParseResult.failure(
        'No MTN MoMo rule family matched this message',
      );
    }
    return ParseResult.success(draft);
  }

  TransactionDraft? _paymentDraft(String body, CaptureInput capture) {
    final match = _payment.firstMatch(body);
    if (match == null) return null;
    final amount = ParsingUtils.amountMinorFrom(match, 1);
    if (amount == null) return null;
    final note = _paymentNote.firstMatch(body)?.group(1)?.trim();
    return _draft(
      capture: capture,
      amountMinor: amount,
      typeHint: 'payment',
      merchant: match.group(2)!.trim(),
      description: _meaningfulNote(note),
      transactedAt: _dateTimeFrom(match, 3),
    );
  }

  TransactionDraft? _sendDraft(String body, CaptureInput capture) {
    final match = _transferred.firstMatch(body);
    if (match == null) return null;
    final amount = ParsingUtils.amountMinorFrom(match, 1);
    if (amount == null) return null;
    return _draft(
      capture: capture,
      amountMinor: amount,
      typeHint: 'send',
      merchant: match.group(2)!.trim(),
      transactedAt: _dateTimeFrom(match, 5),
      metadata: {
        'recipient_phone': match.group(3),
        'wallet_account': match.group(4),
      },
    );
  }

  TransactionDraft _draft({
    required CaptureInput capture,
    required int amountMinor,
    required String typeHint,
    required String merchant,
    String? description,
    DateTime? transactedAt,
    Map<String, Object?> metadata = const {},
  }) {
    return TransactionDraft(
      amountMinor: amountMinor,
      direction: TxDirection.debit,
      source: capture.channel == CaptureChannel.notification
          ? TxSource.notification
          : TxSource.sms,
      transactedAt: transactedAt ?? capture.receivedAt,
      merchant: merchant,
      description: description,
      paymentMethod: 'mobile_money',
      externalRef: _txnId.firstMatch(capture.body)?.group(1),
      confidence: 1,
      balanceMinor: ParsingUtils.balanceMinor(capture.body),
      typeHint: typeHint,
      metadata: {'family': typeHint, ...metadata},
    );
  }

  static DateTime? _dateTimeFrom(RegExpMatch match, int yearGroup) {
    return DateTime(
      int.parse(match.group(yearGroup)!),
      int.parse(match.group(yearGroup + 1)!),
      int.parse(match.group(yearGroup + 2)!),
      int.parse(match.group(yearGroup + 3)!),
      int.parse(match.group(yearGroup + 4)!),
      int.parse(match.group(yearGroup + 5)!),
    );
  }

  static String? _meaningfulNote(String? note) {
    if (note == null || note.isEmpty) return null;
    if (RegExp(r'^0+$').hasMatch(note)) return null;
    return note;
  }
}
