import 'dart:convert';

import 'package:equatable/equatable.dart';

/// What kind of move a fee band applies to.
enum FeeOperation {
  cashOut,
  sendSameNetwork,
  sendOtherNetwork,
  payMerchant,
  walletToBank,
  bankToWallet,
  atmWithdraw;

  static const Map<FeeOperation, String> _names = {
    cashOut: 'cash_out',
    sendSameNetwork: 'send_same_network',
    sendOtherNetwork: 'send_other_network',
    payMerchant: 'pay_merchant',
    walletToBank: 'wallet_to_bank',
    bankToWallet: 'bank_to_wallet',
    atmWithdraw: 'atm_withdraw',
  };

  String get wireName => _names[this]!;

  static FeeOperation? tryParse(String? name) {
    if (name == null || name.isEmpty) return null;
    for (final entry in _names.entries) {
      if (entry.value == name) return entry.key;
    }
    return null;
  }
}

/// One amount band on the shared tariff list, e.g. Airtel cash-out
/// K0–K150 costs K2.50.
class FeeBand extends Equatable {
  const FeeBand({
    required this.id,
    required this.providerKey,
    required this.operation,
    required this.minAmountMinor,
    required this.feeMinor,
    this.maxAmountMinor,
  });

  final String id;

  /// `airtel_money` | `mtn_momo` | `stan_chart`.
  final String providerKey;
  final FeeOperation operation;

  /// Inclusive lower bound, in ngwee.
  final int minAmountMinor;

  /// Inclusive upper bound, in ngwee. Null means no ceiling.
  final int? maxAmountMinor;

  /// Fixed fee for this band, in ngwee.
  final int feeMinor;

  bool covers(int amountMinor) {
    if (amountMinor < minAmountMinor) return false;
    final max = maxAmountMinor;
    if (max == null) return true;
    return amountMinor <= max;
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'providerKey': providerKey,
    'operation': operation.wireName,
    'minAmountMinor': minAmountMinor,
    'maxAmountMinor': maxAmountMinor,
    'feeMinor': feeMinor,
  };

  static FeeBand? tryParse(Map<String, Object?> json) {
    final id = json['id'] as String?;
    final providerKey = json['providerKey'] as String?;
    final operation = FeeOperation.tryParse(json['operation'] as String?);
    final minAmountMinor = _asInt(json['minAmountMinor']);
    final feeMinor = _asInt(json['feeMinor']);
    if (id == null ||
        id.isEmpty ||
        providerKey == null ||
        providerKey.isEmpty ||
        operation == null ||
        minAmountMinor == null ||
        feeMinor == null ||
        minAmountMinor < 0 ||
        feeMinor < 0) {
      return null;
    }
    final maxAmountMinor = _asInt(json['maxAmountMinor']);
    if (maxAmountMinor != null && maxAmountMinor < minAmountMinor) {
      return null;
    }
    return FeeBand(
      id: id,
      providerKey: providerKey,
      operation: operation,
      minAmountMinor: minAmountMinor,
      maxAmountMinor: maxAmountMinor,
      feeMinor: feeMinor,
    );
  }

  static int? _asInt(Object? value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.round();
    if (value is String) return int.tryParse(value);
    return null;
  }

  @override
  List<Object?> get props => [
    id,
    providerKey,
    operation,
    minAmountMinor,
    maxAmountMinor,
    feeMinor,
  ];
}

/// Cached copy of the admin-edited tariff list.
class FeeSchedule extends Equatable {
  const FeeSchedule({
    this.bands = const [],
    this.fetchedAt,
    this.remoteUpdatedAt,
  });

  static const empty = FeeSchedule();

  final List<FeeBand> bands;
  final DateTime? fetchedAt;
  final DateTime? remoteUpdatedAt;

  Map<String, Object?> toJson() => {
    'fetchedAt': fetchedAt?.toUtc().toIso8601String(),
    'remoteUpdatedAt': remoteUpdatedAt?.toUtc().toIso8601String(),
    'bands': [for (final band in bands) band.toJson()],
  };

  static FeeSchedule fromJson(Map<String, Object?> json) {
    final rawBands = json['bands'];
    final bands = <FeeBand>[];
    if (rawBands is List) {
      for (final item in rawBands) {
        if (item is Map<String, Object?>) {
          final band = FeeBand.tryParse(item);
          if (band != null) bands.add(band);
        } else if (item is Map) {
          final band = FeeBand.tryParse(Map<String, Object?>.from(item));
          if (band != null) bands.add(band);
        }
      }
    }
    return FeeSchedule(
      bands: bands,
      fetchedAt: _asDate(json['fetchedAt']),
      remoteUpdatedAt: _asDate(json['remoteUpdatedAt'] ?? json['updatedAt']),
    );
  }

  static DateTime? _asDate(Object? value) {
    if (value == null) return null;
    if (value is DateTime) return value.toUtc();
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value)?.toUtc();
    }
    return null;
  }

  @override
  List<Object?> get props => [bands, fetchedAt, remoteUpdatedAt];
}

/// JSON helpers for the on-device cache.
abstract final class FeeScheduleCacheCodec {
  static String encode(FeeSchedule schedule) => jsonEncode(schedule.toJson());

  static FeeSchedule? decode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final map = jsonDecode(raw);
      if (map is! Map) return null;
      return FeeSchedule.fromJson(Map<String, Object?>.from(map));
    } on Object {
      return null;
    }
  }
}
