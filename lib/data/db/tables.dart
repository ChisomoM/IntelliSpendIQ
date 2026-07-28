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
}

@DataClassName('BudgetRow')
class Budgets extends SyncedTable {
  TextColumn get categoryId => text()();

  /// Month key `YYYY-MM`.
  TextColumn get period => text()();

  /// Monthly limit in ngwee.
  IntColumn get amountMinor => integer()();

  /// Whether next month defaults from this budget.
  BoolColumn get carryOver => boolean().withDefault(const Constant(true))();

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {userId, categoryId, period},
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
