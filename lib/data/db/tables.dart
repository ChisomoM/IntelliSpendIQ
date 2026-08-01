import 'package:drift/drift.dart';

/// Sync-ready columns shared by every table (plan §6.1). Sync is
/// deferred (D37) but the columns exist from day one so onboarding a
/// backend later needs no schema migration. Timestamps are ISO-8601 UTC
/// strings; `updated_at` becomes the LWW field when sync lands (D35).
abstract class SyncedTable extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get createdAt => text()();
  TextColumn get updatedAt => text()();
  TextColumn get deletedAt => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('AccountRow')
class Accounts extends SyncedTable {
  TextColumn get name => text()();

  /// `cash` | `bank` | `mobile_money` | `card`
  TextColumn get type => text()();
  TextColumn get currency => text().withDefault(const Constant('ZMW'))();
  BoolColumn get isDefault => boolean().withDefault(const Constant(false))();

  /// Parser provider key this account captures from,
  /// e.g. `airtel_money` | `stan_chart`.
  TextColumn get providerKey => text().nullable()();

  /// A manually-set balance checkpoint, in ngwee. SMS delivery isn't
  /// reliable enough to treat a reported balance as ground truth, so
  /// this only moves when the user explicitly sets it — the app's
  /// displayed balance is this figure plus every transaction/transfer
  /// recorded against the account since [balanceAsOf].
  IntColumn get balanceMinor => integer().nullable()();

  /// When [balanceMinor] was set. Null means no checkpoint has ever
  /// been set, so the displayed balance sums the account's entire
  /// transaction history instead.
  TextColumn get balanceAsOf => text().nullable()();
}

@DataClassName('CategoryRow')
class Categories extends SyncedTable {
  TextColumn get name => text()();
  TextColumn get icon => text().nullable()();
  TextColumn get color => text().nullable()();
  TextColumn get parentId => text().nullable()();
  BoolColumn get isSystem => boolean().withDefault(const Constant(false))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  /// `expense` | `income`.
  TextColumn get categoryType =>
      text().withDefault(const Constant('expense'))();

  /// Standing template for new budget periods (expense limit or income
  /// plan), in ngwee. Live envelopes for a given period live in
  /// [CategoryBudgets]; this column seeds new periods and the Categories
  /// editor.
  IntColumn get budgetedAmountMinor => integer().nullable()();
}

@DataClassName('TransactionRow')
@TableIndex(name: 'idx_tx_user_date', columns: {#userId, #transactedAt})
@TableIndex(name: 'idx_tx_user_status', columns: {#userId, #status})
@TableIndex(
  name: 'idx_tx_fuzzy',
  columns: {#amountMinor, #merchant, #transactedAt},
)
class Transactions extends SyncedTable {
  TextColumn get accountId => text()();
  TextColumn get categoryId => text().nullable()();

  /// Absolute amount in ngwee (D60).
  IntColumn get amountMinor => integer()();
  TextColumn get currency => text().withDefault(const Constant('ZMW'))();

  /// `debit` | `credit`
  TextColumn get direction => text()();
  TextColumn get merchant => text().nullable()();
  TextColumn get description => text().nullable()();
  TextColumn get transactedAt => text()();

  /// `manual` | `sms` | `notification` | `voice`
  TextColumn get source => text()();
  RealColumn get confidence => real().nullable()();

  /// `confirmed` | `needs_review` | `duplicate_suspect`
  TextColumn get status => text()();
  TextColumn get rawCaptureId => text().nullable()();
  TextColumn get idempotencyKey => text().unique()();
  TextColumn get duplicateOfId => text().nullable()();

  /// `cash` | `mobile_money` | `card` | `bank` | …
  TextColumn get paymentMethod => text().nullable()();

  /// Provider TID / bank reference.
  TextColumn get externalRef => text().nullable()();
  TextColumn get metadataJson => text().nullable()();

  /// Path to a receipt photo copied into app-local storage, if attached.
  TextColumn get receiptPath => text().nullable()();

  /// Structured payee, when one was picked rather than left as free
  /// text in [merchant]/[description].
  TextColumn get payeeId => text().nullable()();

  /// Set when the user says "not a transfer" on a suggested transfer
  /// pairing, so the same two legs stop being re-suggested. Never
  /// cleared back to null.
  TextColumn get transferDismissedAt => text().nullable()();
}

/// A structured payee, selectable on the expense form as an
/// alternative to the free-text merchant field.
@DataClassName('PayeeRow')
class Payees extends SyncedTable {
  TextColumn get name => text()();
}

/// A tag attachable to any number of transactions, for cross-cutting
/// grouping beyond category (e.g. "Work trip", "Tax deductible").
@DataClassName('LabelRow')
class Labels extends SyncedTable {
  TextColumn get name => text()();
  TextColumn get color => text().nullable()();
}

/// Many-to-many link between transactions and labels. Not a
/// [SyncedTable] — a join row has no lifecycle of its own beyond
/// existing or not.
class TransactionLabels extends Table {
  TextColumn get transactionId => text()();
  TextColumn get labelId => text()();

  @override
  Set<Column<Object>> get primaryKey => {transactionId, labelId};
}

/// Overall monthly spending budget — independent of per-category
/// budget envelopes on [Categories]. Category limits allocate under
/// this total; they do not define it.
///
/// Legacy rows use [period] as `YYYY-MM`. New budget periods store the
/// overall amount on [BudgetPeriods] instead; this table remains for
/// migration and older backups.
@DataClassName('OverallBudgetRow')
class OverallBudgets extends SyncedTable {
  /// Month key `YYYY-MM`.
  TextColumn get period => text()();

  /// Total monthly budget in ngwee.
  IntColumn get amountMinor => integer()();

  /// Whether next month defaults from this budget.
  BoolColumn get carryOver => boolean().withDefault(const Constant(true))();

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {userId, period},
  ];
}

/// How the user generates successive budget periods (calendar month,
/// payday cycle, weekly, …). One active schedule per user for now.
@DataClassName('BudgetScheduleRow')
class BudgetSchedules extends SyncedTable {
  /// See [BudgetCadence.dbName].
  TextColumn get cadence => text()();

  /// Day of month for payday cadence (1–31).
  IntColumn get anchorDay => integer().nullable()();

  /// Local `YYYY-MM-DD` anchor for biweekly / every-four-weeks.
  TextColumn get anchorDate => text().nullable()();

  /// `DateTime` weekday (1=Mon…7=Sun) for weekly cadence.
  IntColumn get startWeekday => integer().nullable()();
}

/// One concrete budget window. Half-open `[startAt, endAt)` UTC ISO.
@DataClassName('BudgetPeriodRow')
@TableIndex(name: 'idx_budget_period_bounds', columns: {#userId, #startAt})
class BudgetPeriods extends SyncedTable {
  TextColumn get scheduleId => text()();
  TextColumn get startAt => text()();
  TextColumn get endAt => text()();

  /// Display label `DD/MM/YYYY – DD/MM/YYYY`.
  TextColumn get label => text()();

  /// Overall spending plan for this period, in ngwee.
  IntColumn get overallAmountMinor => integer().nullable()();

  BoolColumn get carryOver => boolean().withDefault(const Constant(true))();

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {userId, startAt, endAt},
  ];
}

/// Per-period category envelope (expense limit or income plan).
@DataClassName('CategoryBudgetRow')
class CategoryBudgets extends SyncedTable {
  TextColumn get periodId => text()();
  TextColumn get categoryId => text()();
  IntColumn get amountMinor => integer()();

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {userId, periodId, categoryId},
  ];
}

/// Money moved between two of the user's own accounts — e.g. a bank
/// withdrawal into mobile money. Recorded as its own entity rather
/// than as a debit + credit transaction pair, so it never counts
/// toward spend or income totals: the two originating transaction
/// legs are soft-deleted once linked into one of these.
@DataClassName('TransferRow')
class Transfers extends SyncedTable {
  TextColumn get fromAccountId => text()();
  TextColumn get toAccountId => text()();

  /// Absolute amount in ngwee (D60).
  IntColumn get amountMinor => integer()();
  TextColumn get transactedAt => text()();
  TextColumn get note => text().nullable()();

  /// The two transaction legs this transfer was linked from, if any —
  /// kept for audit trail (both are soft-deleted, not removed).
  TextColumn get fromTransactionId => text().nullable()();
  TextColumn get toTransactionId => text().nullable()();
}

/// A user-added SMS sender ID routed to an existing provider parser —
/// e.g. a bank that sends alerts from a shortcode the built-in parser
/// doesn't already recognize.
@DataClassName('CustomSenderRow')
class CustomSenderIds extends SyncedTable {
  /// Which provider parser this sender's messages should route to,
  /// e.g. `airtel_money` | `stan_chart`.
  TextColumn get providerKey => text()();

  /// Normalized via `Ids.normalizeSender` before storage.
  TextColumn get senderId => text()();

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {userId, senderId},
  ];
}

/// A learned merchant → category mapping. Seeded implicitly the first
/// time a user recategorizes a transaction from a given merchant
/// (`MerchantCategorizer.learnFrom`); every later capture from that
/// same normalized merchant is auto-categorized from this row instead
/// of falling through to the static keyword rules.
@DataClassName('MerchantCategoryRuleRow')
class MerchantCategoryRules extends SyncedTable {
  /// Via `DedupeService.normalizeMerchant` — the same normalization
  /// fuzzy dedupe already uses, so one merchant maps to one key however
  /// its casing/punctuation varies message to message.
  TextColumn get normalizedMerchant => text()();
  TextColumn get categoryId => text()();

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {userId, normalizedMerchant},
  ];
}

@DataClassName('RawCaptureRow')
@TableIndex(name: 'idx_raw_hash', columns: {#contentHash})
@TableIndex(name: 'idx_raw_status', columns: {#userId, #parseStatus})
class RawCaptures extends SyncedTable {
  /// `sms_inbox` | `notification` | `voice_transcript`
  TextColumn get sourceChannel => text()();

  /// SMS address or notification package.
  TextColumn get sender => text().nullable()();

  /// The captured text. Never dropped (D23).
  TextColumn get body => text()();
  TextColumn get receivedAt => text()();

  /// Native SMS `_id`, for backfill dedupe.
  TextColumn get androidSmsId => text().nullable()();
  TextColumn get packageName => text().nullable()();

  /// `pending` | `parsed` | `failed` | `ignored`
  TextColumn get parseStatus => text().withDefault(const Constant('pending'))();
  TextColumn get parserKey => text().nullable()();
  TextColumn get error => text().nullable()();
  TextColumn get parsedTransactionId => text().nullable()();
  TextColumn get contentHash => text()();
}

/// Small local key-value store for non-secret app state (backfill
/// watermark, onboarding flags). Secrets live in the Keystore-backed
/// secure storage, never here.
@DataClassName('SettingRow')
class Settings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}
