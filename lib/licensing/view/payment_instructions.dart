import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intellispendiq/design/design.dart';
import 'package:intellispendiq/licensing/billing_constants.dart';
import 'package:url_launcher/url_launcher.dart';

Future<void> openSubscriptionWhatsApp() async {
  final uri = BillingConstants.whatsAppUri;
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}

Future<void> copyPaymentNumber(BuildContext context) async {
  await Clipboard.setData(
    const ClipboardData(text: BillingConstants.paymentNumber),
  );
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Payment number copied')),
  );
}

/// Shared payment instructions used by the paywall sheet and hard-block screen.
class PaymentInstructions extends StatelessWidget {
  const PaymentInstructions({
    super.key,
    this.onDismiss,
    this.showDismiss = false,
  });

  final VoidCallback? onDismiss;
  final bool showDismiss;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          BillingConstants.paywallTitle,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: Space.x2),
        Text(
          BillingConstants.paywallBody,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: Space.x1),
        SelectableText(
          BillingConstants.paymentNumber,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: Space.x3),
        FilledButton.icon(
          onPressed: openSubscriptionWhatsApp,
          icon: const Icon(Icons.chat),
          label: const Text('Open WhatsApp'),
        ),
        const SizedBox(height: Space.x1),
        OutlinedButton.icon(
          onPressed: () => copyPaymentNumber(context),
          icon: const Icon(Icons.copy),
          label: const Text('Copy number'),
        ),
        if (showDismiss && onDismiss != null) ...[
          const SizedBox(height: Space.x1),
          TextButton(onPressed: onDismiss, child: const Text('Dismiss')),
        ],
      ],
    );
  }
}

Future<void> showPaywallModal(
  BuildContext context, {
  required bool canDismiss,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    isDismissible: canDismiss,
    enableDrag: canDismiss,
    builder: (context) {
      return SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            Space.gutter,
            Space.x3,
            Space.gutter,
            MediaQuery.viewInsetsOf(context).bottom + Space.x3,
          ),
          child: PaymentInstructions(
            showDismiss: canDismiss,
            onDismiss: canDismiss ? () => Navigator.of(context).pop() : null,
          ),
        ),
      );
    },
  );
}
