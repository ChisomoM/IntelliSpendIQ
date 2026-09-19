import 'package:intellispendiq/core/ids.dart';
import 'package:intellispendiq/data/repositories/account_repository.dart';
import 'package:intellispendiq/data/repositories/budget_period_repository.dart';
import 'package:intellispendiq/data/repositories/category_repository.dart';
import 'package:intellispendiq/data/repositories/raw_capture_repository.dart';
import 'package:intellispendiq/data/repositories/transaction_repository.dart';
import 'package:intellispendiq/data/repositories/fee_schedule_repository.dart';
import 'package:intellispendiq/domain/models/capture_input.dart';
import 'package:intellispendiq/domain/models/enums.dart';
import 'package:intellispendiq/domain/models/parse_result.dart';
import 'package:intellispendiq/domain/models/raw_capture.dart';
import 'package:intellispendiq/domain/models/transaction.dart';
import 'package:intellispendiq/domain/models/transaction_draft.dart';
import 'package:intellispendiq/domain/parsers/parser_registry.dart';
import 'package:intellispendiq/domain/services/dedupe_service.dart';
import 'package:intellispendiq/domain/services/fee_lookup.dart';
import 'package:intellispendiq/domain/services/merchant_categorizer.dart';

/// What happened to one ingested capture.
enum IngestStatus {
  /// Stored and auto-saved as a confirmed transaction.
  saved,

  /// Stored; parsed but flagged as a duplicate suspect for review.
  duplicateSuspect,

  /// Hard duplicate of an already-stored transaction; nothing inserted.
  alreadyCaptured,

  /// Stored raw; parsing failed — surfaced in the Review Inbox.
  parseFailed,

  /// Stored raw; sender is not a known provider.
  ignored,

  /// Exact same capture was already stored (re-delivery / re-backfill).
  skippedExisting,
}

class IngestResult {
  const IngestResult(this.status, {this.rawCapture, this.transaction});

  final IngestStatus status;
  final RawCapture? rawCapture;
  final Transaction? transaction;
}

/// The core capture loop (plan §5):
/// capture → persist raw → parse → dedupe → route
///   → auto-save (confirmed) OR review inbox.
///
/// Reliability rule: the raw body is persisted before parsing is even
/// attempted, so no financial event is ever silently dropped (D23).
class CaptureService {
  CaptureService({
    required ParserRegistry registry,
    required RawCaptureRepository rawCaptures,
    required TransactionRepository transactions,
    required AccountRepository accounts,
    required CategoryRepository categories,
    required BudgetPeriodRepository budgetPeriods,
    required DedupeService dedupe,
    required MerchantCategorizer categorizer,
    FeeScheduleRepository? fees,
  }) : _registry = registry,
       _rawCaptures = rawCaptures,
       _transactions = transactions,
       _accounts = accounts,
       _categories = categories,
       _budgetPeriods = budgetPeriods,
       _dedupe = dedupe,
       _categorizer = categorizer,
       _fees = fees;

  final ParserRegistry _registry;
  final RawCaptureRepository _rawCaptures;
  final TransactionRepository _transactions;
  final AccountRepository _accounts;
  final CategoryRepository _categories;
  final BudgetPeriodRepository _budgetPeriods;
  final DedupeService _dedupe;
  final MerchantCategorizer _categorizer;
  final FeeScheduleRepository? _fees;

  Future<IngestResult> ingest(CaptureInput input) async {
    // 1. Skip captures we have already stored (re-delivery, re-backfill).
    if (input.androidSmsId != null) {
      final existing = await _rawCaptures.byAndroidSmsId(input.androidSmsId!);
      if (existing != null) {
        return IngestResult(
          IngestStatus.skippedExisting,
          rawCapture: existing,
        );
      }
    }
    final hash = Ids.contentHash(
      sender: input.sender ?? input.packageName ?? '',
      body: input.body,
      receivedAt: input.receivedAt,
    );
    final existingByHash = await _rawCaptures.byContentHash(hash);
    if (existingByHash != null) {
      return IngestResult(
        IngestStatus.skippedExisting,
        rawCapture: existingByHash,
      );
    }

    // 2. Persist the raw capture before parsing — never drop.
    final raw = await _rawCaptures.insert(input, contentHash: hash);

    // 3. Route to a provider parser by sender.
    final parsed = _registry.parse(input);
    if (parsed == null) {
      await _rawCaptures.markIgnored(raw.id, error: 'unknown_sender');
      return IngestResult(IngestStatus.ignored, rawCapture: raw);
    }
    final (provider, result) = parsed;

    switch (result) {
      case ParseFailure(:final reason):
        await _rawCaptures.markFailed(
          raw.id,
          parserKey: provider.key,
          error: reason,
        );
        return IngestResult(IngestStatus.parseFailed, rawCapture: raw);

      case ParseSuccess(:final draft):
        return _persistDraft(
          draft,
          raw: raw,
          providerKey: provider.key,
          contentHash: hash,
        );
    }
  }

  Future<IngestResult> _persistDraft(
    TransactionDraft rawDraft, {
    required RawCapture raw,
    required String providerKey,
    required String contentHash,
  }) async {
    // Deterministic merchant categorization (plan: never guess with an
    // LLM on the SMS path) — a learned correction wins, then the
    // keyword table; a miss leaves the category unassigned exactly as
    // before.
    final draft = rawDraft.categoryId != null
        ? rawDraft
        : rawDraft.copyWith(
            categoryId: await _categorizer.categorize(
              merchant: rawDraft.merchant,
              messageBody: raw.body,
            ),
          );
    final account = await _accounts.findOrCreateForProvider(providerKey);
    final idempotencyKey = Ids.idempotencyKey(
      providerKey: providerKey,
      externalRef: draft.externalRef,
      contentHash: contentHash,
    );
    final periodId = (await _budgetPeriods.ensurePeriodContaining(
      draft.transactedAt,
    )).id;

    // 4. Dedupe: hard (skip + link) then fuzzy (flag, never drop).
    final outcome = await _dedupe.check(draft, idempotencyKey: idempotencyKey);
    switch (outcome) {
      case DedupeHard(:final existing):
        await _rawCaptures.markParsed(
          raw.id,
          parserKey: providerKey,
          transactionId: existing.id,
        );
        return IngestResult(
          IngestStatus.alreadyCaptured,
          rawCapture: raw,
          transaction: existing,
        );

      case DedupeFuzzy(:final existing):
        final transaction = await _transactions.insertDraft(
          draft,
          accountId: account.id,
          idempotencyKey: idempotencyKey,
          status: TxStatus.duplicateSuspect,
          rawCaptureId: raw.id,
          duplicateOfId: existing.id,
          periodId: periodId,
        );
        await _rawCaptures.markParsed(
          raw.id,
          parserKey: providerKey,
          transactionId: transaction.id,
        );
        return IngestResult(
          IngestStatus.duplicateSuspect,
          rawCapture: raw,
          transaction: transaction,
        );

      case DedupeNone():
        // 5. Auto-save. Deterministic parses are fully trusted (they
        //    carry confidence 1.0); category stays unassigned until the
        //    user tags it — that is not a blocker for saving.
        final transaction = await _transactions.insertDraft(
          draft,
          accountId: account.id,
          idempotencyKey: idempotencyKey,
          status: TxStatus.confirmed,
          rawCaptureId: raw.id,
          periodId: periodId,
        );
        await _rawCaptures.markParsed(
          raw.id,
          parserKey: providerKey,
          transactionId: transaction.id,
        );
        await _recordFeeIfAny(
          draft,
          accountId: account.id,
          providerKey: providerKey,
          parentTransactionId: transaction.id,
          idempotencyKey: idempotencyKey,
          rawCaptureId: raw.id,
          periodId: periodId,
        );
        // draft.balanceMinor (the provider's stated balance, if the
        // message included one) is deliberately not applied here — SMS
        // delivery isn't reliable enough to treat as ground truth. The
        // account's balance is computed from its transaction ledger
        // instead (AccountRepository.watchComputedBalances).
        return IngestResult(
          IngestStatus.saved,
          rawCapture: raw,
          transaction: transaction,
        );
    }
  }

  /// Provider charges and tariff-list matches become their own fee
  /// line, categorized as Fees/Charges.
  Future<void> _recordFeeIfAny(
    TransactionDraft draft, {
    required String accountId,
    required String providerKey,
    required String parentTransactionId,
    required String idempotencyKey,
    required String rawCaptureId,
    required String periodId,
  }) async {
    var fee = draft.feeMinor;
    var source = 'sms';
    String? scheduleBandId;
    if (fee == null || fee <= 0) {
      final fees = _fees;
      if (fees == null) return;
      final schedule = await fees.current();
      final band = FeeLookup.bandForDraft(
        schedule: schedule,
        providerKey: providerKey,
        draft: draft,
      );
      if (band == null || band.feeMinor <= 0) return;
      fee = band.feeMinor;
      source = 'schedule';
      scheduleBandId = band.id;
    }
    final feeCategory = await _categories.byName('Fees/Charges');
    await _transactions.insertDraft(
      TransactionDraft(
        amountMinor: fee,
        direction: TxDirection.debit,
        source: draft.source,
        transactedAt: draft.transactedAt,
        merchant: draft.merchant,
        description: 'Charge for ${draft.merchant ?? 'transaction'}',
        categoryId: feeCategory?.id,
        paymentMethod: draft.paymentMethod,
        confidence: draft.confidence,
        typeHint: 'fee',
        metadata: {
          'family': 'fee',
          'source': source,
          'parentTransactionId': parentTransactionId,
          if (scheduleBandId != null) 'scheduleBandId': scheduleBandId,
        },
      ),
      accountId: accountId,
      idempotencyKey: '$idempotencyKey:fee',
      status: TxStatus.confirmed,
      rawCaptureId: rawCaptureId,
      periodId: periodId,
    );
  }
}
