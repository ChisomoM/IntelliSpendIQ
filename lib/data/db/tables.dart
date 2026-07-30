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

  /// Cached balance from the latest provider SMS, informational only.
  IntColumn get balanceMinor => integer().nullable()();
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

  /// A standing monthly limit (expense) or planned figure (income), in
  /// ngwee. Applies to whichever period is currently viewed — there is
  /// no separate per-month row to carry forward, unlike the old
  /// [Budgets] table this replaced.
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
