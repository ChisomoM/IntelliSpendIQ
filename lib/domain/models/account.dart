import 'package:equatable/equatable.dart';
import 'package:intellispendiq/domain/models/enums.dart';

/// A money account — mobile money, bank, cash, or card.
class Account extends Equatable {
  const Account({
    required this.id,
    required this.name,
    required this.type,
    this.currency = 'ZMW',
    this.isDefault = false,
    this.providerKey,
    this.balanceMinor,
  });

  final String id;
  final String name;
  final AccountType type;
  final String currency;
  final bool isDefault;

  /// Parser provider key this account captures from, e.g. `airtel_money`.
  final String? providerKey;

  /// Cached balance from the latest provider SMS. Informational only —
  /// never the source of truth for spend totals.
  final int? balanceMinor;

  @override
  List<Object?> get props => [
    id,
    name,
    type,
    currency,
    isDefault,
    providerKey,
    balanceMinor,
  ];
}
