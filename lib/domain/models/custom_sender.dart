import 'package:equatable/equatable.dart';

/// A user-added SMS sender ID routed to an existing provider parser —
/// e.g. a bank sending alerts from a shortcode the built-in parser
/// doesn't already recognize.
class CustomSender extends Equatable {
  const CustomSender({
    required this.id,
    required this.providerKey,
    required this.senderId,
  });

  final String id;

  /// e.g. `airtel_money` | `stan_chart`.
  final String providerKey;

  /// Already normalized via `Ids.normalizeSender`.
  final String senderId;

  @override
  List<Object?> get props => [id, providerKey, senderId];
}
