import 'package:equatable/equatable.dart';

/// One declared income stream for a month. A month can have several —
/// e.g. "Salary" and "Side hustle" — tracked together against overall
/// spend rather than just per-category budget limits.
class MonthlyIncome extends Equatable {
  const MonthlyIncome({
    required this.id,
    required this.period,
    required this.amountMinor,
    this.label,
  });

  final String id;

  /// Month key, `YYYY-MM`.
  final String period;

  /// Declared income in ngwee.
  final int amountMinor;

  /// Names this stream among possibly several for the same month, e.g.
  /// "Salary" vs "Side hustle". Null on the original single-figure
  /// entry from before multiple streams existed.
  final String? label;

  /// What a list or editor shows when a stream has no label.
  String get displayLabel =>
      label?.trim().isNotEmpty ?? false ? label! : 'Income';

  @override
  List<Object?> get props => [id, period, amountMinor, label];
}
