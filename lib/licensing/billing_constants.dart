/// Offline MoMo payment instructions shown in the paywall / hard-block UI.
abstract final class BillingConstants {
  static const paymentNumber = '0972682268';

  /// Zambia country code + local number without leading 0.
  static const whatsAppE164 = '260972682268';

  static const whatsAppMessage =
      'Hi, I paid for IntelliSpendIQ. Here is my transaction reference screenshot.';

  static Uri get whatsAppUri => Uri.parse(
    'https://wa.me/$whatsAppE164?text=${Uri.encodeComponent(whatsAppMessage)}',
  );

  static const paywallTitle = 'Activate subscription';

  static const paywallBody =
      'Send payment to $paymentNumber, then WhatsApp the successful '
      'transaction reference screenshot to get activated.';
}
