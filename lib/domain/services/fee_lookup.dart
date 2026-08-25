import 'package:intellispendiq/domain/models/account.dart';
import 'package:intellispendiq/domain/models/enums.dart';
import 'package:intellispendiq/domain/models/fee_schedule.dart';
import 'package:intellispendiq/domain/models/transaction_draft.dart';
import 'package:intellispendiq/domain/parsers/airtel_money_parser.dart';
import 'package:intellispendiq/domain/parsers/mtn_momo_parser.dart';

/// Looks up a fee from the shared tariff list. Pure — no I/O.
abstract final class FeeLookup {
  /// Prefill text for an amount field, e.g. `2.50`. Empty when no fee.
  static String fieldText(int? feeMinor) {
    if (feeMinor == null || feeMinor <= 0) return '';
    return (feeMinor / 100).toStringAsFixed(2);
  }

  static int? forTransfer({
    required FeeSchedule schedule,
    required Account from,
    required Account to,
    required int amountMinor,
  }) {
    final operation = operationForTransfer(from, to);
    if (operation == null) return null;
    final providerKey = _providerForTransfer(from, to, operation);
    if (providerKey == null) return null;
    return feeFor(
      schedule: schedule,
      providerKey: providerKey,
      operation: operation,
      amountMinor: amountMinor,
    );
  }

  static int? forDraft({
    required FeeSchedule schedule,
    required String providerKey,
    required TransactionDraft draft,
  }) {
    return bandForDraft(
      schedule: schedule,
      providerKey: providerKey,
      draft: draft,
    )?.feeMinor;
  }

  static FeeBand? bandForDraft({
    required FeeSchedule schedule,
    required String providerKey,
    required TransactionDraft draft,
  }) {
    if (draft.direction == TxDirection.credit) return null;
    final operation = operationForDraft(
      draft,
      senderProviderKey: providerKey,
    );
    if (operation == null) return null;
    return bandFor(
      schedule: schedule,
      providerKey: providerKey,
      operation: operation,
      amountMinor: draft.amountMinor,
    );
  }

  static int? feeFor({
    required FeeSchedule schedule,
    required String providerKey,
    required FeeOperation operation,
    required int amountMinor,
  }) {
    final matches = [
      for (final band in schedule.bands)
        if (band.providerKey == providerKey &&
            band.operation == operation &&
            band.covers(amountMinor))
          band,
    ];
    if (matches.isEmpty) return null;
    matches.sort(_narrowestFirst);
    return matches.first.feeMinor;
  }

  static FeeBand? bandFor({
    required FeeSchedule schedule,
    required String providerKey,
    required FeeOperation operation,
    required int amountMinor,
  }) {
    final matches = [
      for (final band in schedule.bands)
        if (band.providerKey == providerKey &&
            band.operation == operation &&
            band.covers(amountMinor))
          band,
    ];
    if (matches.isEmpty) return null;
    matches.sort(_narrowestFirst);
    return matches.first;
  }

  static FeeOperation? operationForTransfer(Account from, Account to) {
    if (from.type == AccountType.mobileMoney && to.type == AccountType.cash) {
      return FeeOperation.cashOut;
    }
    if (from.type == AccountType.mobileMoney &&
        to.type == AccountType.mobileMoney) {
      if (from.providerKey != null &&
          to.providerKey != null &&
          from.providerKey == to.providerKey) {
        return FeeOperation.sendSameNetwork;
      }
      return FeeOperation.sendOtherNetwork;
    }
    if (from.type == AccountType.mobileMoney && to.type == AccountType.bank) {
      return FeeOperation.walletToBank;
    }
    if (from.type == AccountType.bank && to.type == AccountType.mobileMoney) {
      return FeeOperation.bankToWallet;
    }
    if (from.type == AccountType.bank && to.type == AccountType.cash) {
      return FeeOperation.atmWithdraw;
    }
    return null;
  }

  static FeeOperation? operationForDraft(
    TransactionDraft draft, {
    required String senderProviderKey,
  }) {
    if (draft.direction == TxDirection.credit) return null;
    final family = (draft.typeHint ?? draft.metadata['family'] as String?)
        ?.toLowerCase();
    return switch (family) {
      'withdrawal' => FeeOperation.cashOut,
      'send' => _sendOperation(
        senderProviderKey: senderProviderKey,
        recipientPhone: draft.metadata['recipient_phone'] as String?,
      ),
      'paid_to' || 'payment_till' || 'payment' => FeeOperation.payMerchant,
      // Bank SMS amounts may already include the fee — do not guess.
      'txn_to' || 'receive' || 'fee' => null,
      _ => null,
    };
  }

  /// Airtel 097/077, MTN 096/076, Zamtel 095/075 — used to tell same
  /// vs other network on a P2P send. Unknown numbers default to same
  /// network so a fee is still applied.
  static String? networkProviderKeyFromPhone(String? raw) {
    final digits = (raw ?? '').replaceAll(RegExp(r'\D'), '');
    if (digits.length < 2) return null;
    final prefix = _zambiaPrefix(digits);
    if (prefix == null) return null;
    return switch (prefix) {
      '97' || '77' || '57' => AirtelMoneyParser.providerKey,
      '96' || '76' || '66' => MtnMoMoParser.providerKey,
      '95' || '75' || '55' => 'zamtel',
      _ => null,
    };
  }

  static String? _providerForTransfer(
    Account from,
    Account to,
    FeeOperation operation,
  ) {
    return switch (operation) {
      FeeOperation.cashOut ||
      FeeOperation.sendSameNetwork ||
      FeeOperation.sendOtherNetwork ||
      FeeOperation.walletToBank => from.providerKey,
      FeeOperation.bankToWallet ||
      FeeOperation.atmWithdraw => from.providerKey,
      FeeOperation.payMerchant => from.providerKey,
    };
  }

  static FeeOperation _sendOperation({
    required String senderProviderKey,
    required String? recipientPhone,
  }) {
    final recipient = networkProviderKeyFromPhone(recipientPhone);
    if (recipient == null || recipient == senderProviderKey) {
      return FeeOperation.sendSameNetwork;
    }
    return FeeOperation.sendOtherNetwork;
  }

  static String? _zambiaPrefix(String digits) {
    if (digits.startsWith('260') && digits.length >= 5) {
      return digits.substring(3, 5);
    }
    if (digits.startsWith('0') && digits.length >= 3) {
      return digits.substring(1, 3);
    }
    return digits.substring(0, 2);
  }

  static int _narrowestFirst(FeeBand a, FeeBand b) {
    final aSpan = (a.maxAmountMinor ?? 1 << 30) - a.minAmountMinor;
    final bSpan = (b.maxAmountMinor ?? 1 << 30) - b.minAmountMinor;
    return aSpan.compareTo(bSpan);
  }
}
