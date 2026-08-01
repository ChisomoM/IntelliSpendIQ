import 'package:intellispendiq/domain/models/capture_input.dart';
import 'package:intellispendiq/domain/models/enums.dart';

/// The real SMS corpus from the plan (§21.3), verbatim. Parser tests run
/// against these exact strings so a regression shows up before a real
/// alert is misread.
abstract final class Corpus {
  static const airtelSender = 'AirtelMoney';
  static const airtelNumericSender = '24783566639';
  static const stanChartSender = 'StanChartZM';
  static const stanChartNumericSender = '78262427896';

  static const paymentTillNamed =
      'Payment of K10.00 Till Number SOCHESCARE AIRTEL NETWORKS SELF CARE '
      'SOCHE. Airtel Money bal is K45.23. TID : MP260728.0729.D08222.';

  static const withdrawal =
      'You have withdrawn K200.00 from 20068466 FELIX MONDE. Bal is '
      'K55.23. TID: CO260727.1954.D21146.';

  static const moneySent =
      'Money sent to Sibeso Nyumbu on 979142832.Amount K205.00. Your bal '
      'is K260.23.TID: PP260727.1512.M73944';

  static const paymentTillNumeric =
      'Payment of K1.00 Till Number 300770 GOODFELLOW DIGITAL LIMITED. '
      'Airtel Money bal is K466.53. TID : MP260727.1129.Y34799.';

  static const paidWithCharge =
      'PAID K600.00 to GLOBAL PAY COLLECTIONS Charge K0.00, '
      'TID XX260726.1524.M81597. Bal K601.35 Date: 26-July-2026 15:24. '
      'https://bit.ly/3ZgpiNw';

  static const receivedShorthand =
      'You have received K300 from CHISOMO MUTALE. Txn. ID: '
      'CI260726.1522.A37452. Reason: Mobile Money Transfer.';

  static const moneyReceived =
      'Money received K1350.00 from 0245970 NFS SETTLEMENT ACCOUNT. Dial '
      '*115# to check balance. Deposits are free. TID: CI260726.1451.D36552';

  static const stanChartTransfer =
      'Dear Client, transaction of K300.00 to Airtel has been processed '
      'successfully, ref. ZM2607260050941958 For any queries contact us on  '
      '5247';

  /// Every Airtel sample, for coverage assertions.
  static const List<String> airtelSamples = [
    paymentTillNamed,
    withdrawal,
    moneySent,
    paymentTillNumeric,
    paidWithCharge,
    receivedShorthand,
    moneyReceived,
  ];

  static CaptureInput capture(
    String body, {
    String sender = airtelSender,
    DateTime? receivedAt,
    String? androidSmsId,
  }) => CaptureInput(
    channel: CaptureChannel.smsInbox,
    sender: sender,
    body: body,
    receivedAt: receivedAt ?? DateTime(2026, 7, 28, 9, 30),
    androidSmsId: androidSmsId,
  );
}
