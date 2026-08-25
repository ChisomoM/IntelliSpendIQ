import 'package:flutter_test/flutter_test.dart';
import 'package:intellispendiq/domain/models/account.dart';
import 'package:intellispendiq/domain/models/enums.dart';
import 'package:intellispendiq/domain/models/fee_schedule.dart';
import 'package:intellispendiq/domain/models/transaction_draft.dart';
import 'package:intellispendiq/domain/services/fee_lookup.dart';

void main() {
  const cashOut = FeeBand(
    id: 'airtel-cash-0-150',
    providerKey: 'airtel_money',
    operation: FeeOperation.cashOut,
    minAmountMinor: 0,
    maxAmountMinor: 15000,
    feeMinor: 250,
  );
  const sendSame = FeeBand(
    id: 'airtel-send-same-100',
    providerKey: 'airtel_money',
    operation: FeeOperation.sendSameNetwork,
    minAmountMinor: 0,
    maxAmountMinor: 10000,
    feeMinor: 32,
  );
  const sendOther = FeeBand(
    id: 'airtel-send-other-100',
    providerKey: 'airtel_money',
    operation: FeeOperation.sendOtherNetwork,
    minAmountMinor: 0,
    maxAmountMinor: 10000,
    feeMinor: 150,
  );

  final schedule = FeeSchedule(bands: [cashOut, sendSame, sendOther]);

  const airtel = Account(
    id: 'airtel',
    name: 'Airtel Money',
    type: AccountType.mobileMoney,
    providerKey: 'airtel_money',
  );
  const airtelTwo = Account(
    id: 'airtel-2',
    name: 'Airtel Money 2',
    type: AccountType.mobileMoney,
    providerKey: 'airtel_money',
  );
  const mtn = Account(
    id: 'mtn',
    name: 'MTN MoMo',
    type: AccountType.mobileMoney,
    providerKey: 'mtn_momo',
  );
  const cash = Account(
    id: 'cash',
    name: 'Cash',
    type: AccountType.cash,
  );

  group('FeeLookup.forTransfer', () {
    test('cash-out from MoMo to cash uses the matching band', () {
      expect(
        FeeLookup.forTransfer(
          schedule: schedule,
          from: airtel,
          to: cash,
          amountMinor: 8000,
        ),
        250,
      );
    });

    test('same-network wallet send uses the same-network band', () {
      expect(
        FeeLookup.forTransfer(
          schedule: schedule,
          from: airtel,
          to: airtelTwo,
          amountMinor: 10000,
        ),
        32,
      );
    });

    test('Airtel to MTN is other-network', () {
      expect(
        FeeLookup.forTransfer(
          schedule: schedule,
          from: airtel,
          to: mtn,
          amountMinor: 5000,
        ),
        150,
      );
    });

    test('amount above every band returns null', () {
      expect(
        FeeLookup.forTransfer(
          schedule: schedule,
          from: airtel,
          to: cash,
          amountMinor: 20000,
        ),
        isNull,
      );
    });
  });

  group('FeeLookup.forDraft', () {
    test('withdrawal SMS is cash-out', () {
      final draft = TransactionDraft(
        amountMinor: 20000,
        direction: TxDirection.debit,
        source: TxSource.sms,
        transactedAt: DateTime.utc(2026, 7, 27),
        typeHint: 'withdrawal',
        metadata: const {'family': 'withdrawal'},
      );
      expect(
        FeeLookup.forDraft(
          schedule: const FeeSchedule(
            bands: [
              FeeBand(
                id: 'airtel-cash-wide',
                providerKey: 'airtel_money',
                operation: FeeOperation.cashOut,
                minAmountMinor: 0,
                maxAmountMinor: 50000,
                feeMinor: 250,
              ),
            ],
          ),
          providerKey: 'airtel_money',
          draft: draft,
        ),
        250,
      );
    });

    test('send to an MTN number from Airtel is other-network', () {
      final draft = TransactionDraft(
        amountMinor: 20500,
        direction: TxDirection.debit,
        source: TxSource.sms,
        transactedAt: DateTime.utc(2026, 7, 27),
        typeHint: 'send',
        metadata: const {
          'family': 'send',
          'recipient_phone': '260769953282',
        },
      );
      expect(
        FeeLookup.operationForDraft(
          draft,
          senderProviderKey: 'airtel_money',
        ),
        FeeOperation.sendOtherNetwork,
      );
    });

    test('credits never get a fee', () {
      final draft = TransactionDraft(
        amountMinor: 30000,
        direction: TxDirection.credit,
        source: TxSource.sms,
        transactedAt: DateTime.utc(2026, 7, 26),
        typeHint: 'receive',
      );
      expect(
        FeeLookup.forDraft(
          schedule: schedule,
          providerKey: 'airtel_money',
          draft: draft,
        ),
        isNull,
      );
    });
  });

  group('networkProviderKeyFromPhone', () {
    test('normalises 260, leading zero, and short local numbers', () {
      expect(
        FeeLookup.networkProviderKeyFromPhone('260769953282'),
        'mtn_momo',
      );
      expect(FeeLookup.networkProviderKeyFromPhone('0979142832'), 'airtel_money');
      expect(FeeLookup.networkProviderKeyFromPhone('979142832'), 'airtel_money');
    });
  });
}
