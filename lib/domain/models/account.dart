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
    this.balanceAsOf,
  });

  final String id;
  final String name;
  final AccountType type;
  final String currency;
  final bool isDefault;

  /// Parser provider key this account captures from, e.g. `airtel_money`.
  final String? providerKey;

  /// A manually-set balance checkpoint. The app's displayed balance is
  /// this figure plus every transaction/transfer since [balanceAsOf] —
  /// see `AccountRepository.watchComputedBalances`. Null means no
  /// checkpoint has ever been set.
  final int? balanceMinor;

  /// When [balanceMinor] was set by hand.
  final DateTime? balanceAsOf;

  @override
  List<Object?> get props => [
    id,
    name,
    type,
    currency,
    isDefault,
    providerKey,
    balanceMinor,
    balanceAsOf,
  ];
}
