/// Direction of money movement relative to the owning account.
enum TxDirection {
  debit,
  credit;

  static TxDirection fromName(String name) =>
      TxDirection.values.firstWhere((e) => e.name == name);
}

/// Where a transaction came from.
enum TxSource {
  manual,
  sms,
  notification,
  voice;

  static TxSource fromName(String name) =>
      TxSource.values.firstWhere((e) => e.name == name);
}

/// Lifecycle status of a transaction.
enum TxStatus {
  confirmed,
  needsReview,
  duplicateSuspect,

  /// Recorded but not yet paid — "mark as paid" left unchecked.
  /// Excluded from spend/income totals until confirmed.
  planned;

  static const Map<TxStatus, String> _names = {
    confirmed: 'confirmed',
    needsReview: 'needs_review',
    duplicateSuspect: 'duplicate_suspect',
    planned: 'planned',
  };

  String get dbName => _names[this]!;

  static TxStatus fromDbName(String name) =>
      _names.entries.firstWhere((e) => e.value == name).key;
}

/// Channel a raw capture arrived through.
enum CaptureChannel {
  smsInbox,
  notification,
  voiceTranscript;

  static const Map<CaptureChannel, String> _names = {
    smsInbox: 'sms_inbox',
    notification: 'notification',
    voiceTranscript: 'voice_transcript',
  };

  String get dbName => _names[this]!;

  static CaptureChannel fromDbName(String name) =>
      _names.entries.firstWhere((e) => e.value == name).key;
}

/// Parse lifecycle of a raw capture.
enum ParseStatus {
  pending,
  parsed,
  failed,
  ignored;

  static ParseStatus fromName(String name) =>
      ParseStatus.values.firstWhere((e) => e.name == name);
}

/// Account types supported by the schema (D07).
enum AccountType {
  cash,
  bank,
  mobileMoney,
  card;

  static const Map<AccountType, String> _names = {
    cash: 'cash',
    bank: 'bank',
    mobileMoney: 'mobile_money',
    card: 'card',
  };

  String get dbName => _names[this]!;

  static AccountType fromDbName(String name) =>
      _names.entries.firstWhere((e) => e.value == name).key;
}

/// Whether a category tracks spending or income.
enum CategoryType {
  expense,
  income;

  static const Map<CategoryType, String> _names = {
    expense: 'expense',
    income: 'income',
  };

  String get dbName => _names[this]!;

  static CategoryType fromDbName(String name) =>
      _names.entries.firstWhere((e) => e.value == name).key;
}

/// How successive budget periods are generated for a user.
enum BudgetCadence {
  /// 1st of the month → 1st of next month (default).
  calendarMonth,

  /// Same day each month → same day next month (e.g. payday on the 25th).
  payday,

  weekly,
  biweekly,
  everyFourWeeks,

  /// One-off or irregular ranges; periods are created manually.
  custom;

  static const Map<BudgetCadence, String> _names = {
    calendarMonth: 'calendar_month',
    payday: 'payday',
    weekly: 'weekly',
    biweekly: 'biweekly',
    everyFourWeeks: 'every_four_weeks',
    custom: 'custom',
  };

  String get dbName => _names[this]!;

  static BudgetCadence fromDbName(String name) =>
      _names.entries.firstWhere((e) => e.value == name).key;
}
