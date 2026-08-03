import 'dart:async';
import 'dart:io';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:intellispendiq/core/ids.dart';
import 'package:intellispendiq/core/money.dart';
import 'package:intellispendiq/data/repositories/account_repository.dart';
import 'package:intellispendiq/data/repositories/category_repository.dart';
import 'package:intellispendiq/data/repositories/label_repository.dart';
import 'package:intellispendiq/data/repositories/payee_repository.dart';
import 'package:intellispendiq/data/repositories/raw_capture_repository.dart';
import 'package:intellispendiq/data/repositories/transaction_repository.dart';
import 'package:intellispendiq/data/repositories/transfer_repository.dart';
import 'package:intellispendiq/domain/models/account.dart';
import 'package:intellispendiq/domain/models/category.dart';
import 'package:intellispendiq/domain/models/enums.dart';
import 'package:intellispendiq/domain/models/label.dart';
import 'package:intellispendiq/domain/models/payee.dart';
import 'package:intellispendiq/domain/models/transaction.dart';
import 'package:intellispendiq/domain/models/transaction_draft.dart';
import 'package:intellispendiq/domain/services/merchant_categorizer.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'transaction_entry_state.dart';

/// Backs manual entry and editing, including the "enter manually" path
/// out of the Review Inbox.
class TransactionEntryCubit extends Cubit<TransactionEntryState> {
  TransactionEntryCubit({
    required TransactionRepository transactions,
    required AccountRepository accounts,
    required CategoryRepository categories,
    required PayeeRepository payees,
    required LabelRepository labels,
    required RawCaptureRepository rawCaptures,
    required TransferRepository transfers,
    MerchantCategorizer? categorizer,
    Transaction? existing,
    String? rawCaptureId,
    Future<Directory> Function()? documentsDirectory,
  }) : _transactions = transactions,
       _accounts = accounts,
       _categories = categories,
       _payees = payees,
       _labels = labels,
       _rawCaptures = rawCaptures,
       _transfers = transfers,
       _categorizer = categorizer,
       _existing = existing,
       _rawCaptureId = rawCaptureId,
       _documentsDirectory =
           documentsDirectory ?? getApplicationDocumentsDirectory,
       super(
         existing == null
             ? TransactionEntryState(transactedAt: DateTime.now())
             : TransactionEntryState(
                 amount: (existing.amountMinor / 100).toStringAsFixed(2),
                 merchant: existing.merchant ?? '',
                 description: existing.description ?? '',
                 direction: existing.direction,
                 categoryId: existing.categoryId,
                 accountId: existing.accountId,
                 payeeId: existing.payeeId,
                 isPaid: existing.status != TxStatus.planned,
                 transactedAt: existing.transactedAt.toLocal(),
                 receiptPath: existing.receiptPath,
               ),
       );

  final TransactionRepository _transactions;
  final AccountRepository _accounts;
  final CategoryRepository _categories;
  final PayeeRepository _payees;
  final LabelRepository _labels;
  final RawCaptureRepository _rawCaptures;
  final TransferRepository _transfers;
  final MerchantCategorizer? _categorizer;
  final Transaction? _existing;
  final String? _rawCaptureId;
  final Future<Directory> Function() _documentsDirectory;

  bool get isEditing => _existing != null;

  /// True when this edit screen can offer "This was a transfer" — needs
  /// an existing entry and at least one other account to move money to.
  bool get canConvertToTransfer =>
      isEditing && state.accounts.length >= 2;

  /// Account currently selected on the form (for convert-to-transfer).
  String? get transferSourceAccountId => state.accountId;

  /// Direction currently selected on the form (for convert-to-transfer).
  TxDirection get transferSourceDirection => state.direction;

  /// Prefill for the convert sheet: merchant first, else the note.
  String? get prefilledTransferNote {
    final merchant = state.merchant.trim();
    if (merchant.isNotEmpty) return merchant;
    final description = state.description.trim();
    if (description.isNotEmpty) return description;
    return null;
  }

  /// Fire-and-forget entry point for widget construction.
  void loadOptionsUnawaited() => unawaited(loadOptions());

  /// Loads the pickers' options and defaults the account.
  Future<void> loadOptions() async {
    final categories = await _categories.getAll();
    final accounts = await _accounts.getAll();
    final payees = await _payees.getAll();
    final labels = await _labels.getAll();
    final existing = _existing;
    final labelIds = existing == null
        ? const <String>[]
        : await _transactions.labelIdsFor(existing.id);
    final defaultAccount = accounts.isEmpty
        ? null
        : accounts.firstWhere(
            (a) => a.isDefault,
            orElse: () => accounts.first,
          );
    emit(
      state.copyWith(
        categories: categories,
        accounts: accounts,
        payees: payees,
        labels: labels,
        labelIds: labelIds,
        accountId: state.accountId ?? defaultAccount?.id,
      ),
    );
  }

  void amountChanged(String value) => emit(state.copyWith(amount: value));

  /// Sets the date while keeping the existing clock time, for the
  /// Today/Yesterday shortcuts. Those answer "which day", and a
  /// shortcut that also reset the time to midnight would silently
  /// reorder the entry against everything else captured that day.
  void dayShortcutSelected(DateTime day) {
    final current = state.transactedAt;
    emit(
      state.copyWith(
        transactedAt: DateTime(
          day.year,
          day.month,
          day.day,
          current.hour,
          current.minute,
        ),
      ),
    );
  }

  void merchantChanged(String value) => emit(state.copyWith(merchant: value));

  void descriptionChanged(String value) =>
      emit(state.copyWith(description: value));

  void directionChanged(TxDirection value) =>
      emit(state.copyWith(direction: value));

  void categoryChanged(String? value) =>
      emit(state.copyWith(categoryId: value));

  void accountChanged(String? value) => emit(state.copyWith(accountId: value));

  void dateChanged(DateTime value) => emit(state.copyWith(transactedAt: value));

  void paidChanged(bool value) => emit(state.copyWith(isPaid: value));

  void payeeChanged(String? value) =>
      emit(state.copyWith(payeeId: value, clearPayee: value == null));

  /// Finds or creates a payee by name, then selects it.
  Future<void> payeeAdded(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    final payee = await _payees.findOrCreate(trimmed);
    emit(
      state.copyWith(
        payees: [...state.payees.where((p) => p.id != payee.id), payee],
        payeeId: payee.id,
      ),
    );
  }

  void labelToggled(String labelId) {
    final selected = state.labelIds.contains(labelId)
        ? state.labelIds.where((id) => id != labelId).toList()
        : [...state.labelIds, labelId];
    emit(state.copyWith(labelIds: selected));
  }

  /// Finds or creates a label by name, then selects it.
  Future<void> labelAdded(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    final label = await _labels.findOrCreate(trimmed);
    emit(
      state.copyWith(
        labels: [...state.labels.where((l) => l.id != label.id), label],
        labelIds: [...state.labelIds.where((id) => id != label.id), label.id],
      ),
    );
  }

  /// Copies the picked photo at [sourcePath] into app-local storage so
  /// it survives even if the user later deletes it from wherever they
  /// picked it from, then records its new path.
  Future<void> attachReceipt(String sourcePath) async {
    final documentsDir = await _documentsDirectory();
    final receiptsDir = Directory(p.join(documentsDir.path, 'receipts'));
    await receiptsDir.create(recursive: true);
    final extension = p.extension(sourcePath);
    final destination = p.join(receiptsDir.path, '${Ids.newId()}$extension');
    await File(sourcePath).copy(destination);

    final previous = state.receiptPath;
    emit(state.copyWith(receiptPath: destination));
    if (previous != null) await _tryDelete(previous);
  }

  Future<void> removeReceipt() async {
    final previous = state.receiptPath;
    emit(state.copyWith(clearReceiptPath: true));
    if (previous != null) await _tryDelete(previous);
  }

  Future<void> _tryDelete(String path) async {
    try {
      await File(path).delete();
    } on Object {
      // Best-effort cleanup — an orphaned file costs disk space, not
      // correctness, so a failure here shouldn't block the user.
    }
  }

  /// Validates and writes. "Mark as paid" decides between
  /// [TxStatus.confirmed] and [TxStatus.planned]; editing an
  /// already-planned entry can flip it either way.
  Future<void> submit() async {
    final amountMinor = Money.tryParseToMinor(state.amount);
    if (amountMinor == null || amountMinor <= 0) {
      emit(
        state.copyWith(
          status: TransactionEntryStatus.invalid,
          errorMessage: 'Enter an amount like 25.50',
        ),
      );
      return;
    }

    emit(state.copyWith(status: TransactionEntryStatus.saving));
    final merchant = state.merchant.trim();
    final description = state.description.trim();
    final status = state.isPaid ? TxStatus.confirmed : TxStatus.planned;

    try {
      String transactionId;
      if (isEditing) {
        final existing = _existing!;
        transactionId = existing.id;
        await _transactions.updateFields(
          existing.id,
          amountMinor: amountMinor,
          merchant: merchant.isEmpty ? null : merchant,
          description: description.isEmpty ? null : description,
          categoryId: state.categoryId,
          transactedAt: state.transactedAt,
          status: status,
          payeeId: state.payeeId,
          clearPayee: state.payeeId == null,
          accountId: state.accountId ?? existing.accountId,
          direction: state.direction,
        );
        if (state.receiptPath != existing.receiptPath) {
          await _transactions.setReceiptPath(existing.id, state.receiptPath);
        }
      } else {
        final accountId = state.accountId ?? (await _accounts.getDefault()).id;
        final transaction = await _transactions.insertDraft(
          TransactionDraft(
            amountMinor: amountMinor,
            direction: state.direction,
            source: TxSource.manual,
            transactedAt: state.transactedAt,
            merchant: merchant.isEmpty ? null : merchant,
            description: description.isEmpty ? null : description,
            categoryId: state.categoryId,
            confidence: 1,
            receiptPath: state.receiptPath,
            payeeId: state.payeeId,
          ),
          accountId: accountId,
          idempotencyKey: 'manual:${Ids.newId()}',
          status: status,
          rawCaptureId: _rawCaptureId,
        );
        transactionId = transaction.id;
        if (_rawCaptureId != null) {
          await _rawCaptures.resolveManually(
            _rawCaptureId,
            transactionId: transaction.id,
          );
        }
      }
      await _transactions.setLabels(transactionId, state.labelIds);
      final categoryId = state.categoryId;
      if (categoryId != null && merchant.isNotEmpty) {
        await _categorizer?.learnFrom(
          merchant: merchant,
          categoryId: categoryId,
        );
      }
      emit(state.copyWith(status: TransactionEntryStatus.saved));
    } on Object catch (error) {
      emit(
        state.copyWith(
          status: TransactionEntryStatus.failure,
          errorMessage: 'Could not save: $error',
        ),
      );
    }
  }

  Future<void> delete() async {
    final existing = _existing;
    if (existing == null) return;
    await _transactions.softDelete(existing.id);
    // Leave the receipt file in place so undo can restore the entry
    // fully within the snackbar hold window.
    emit(state.copyWith(status: TransactionEntryStatus.saved));
  }

  /// Matching opposite leg the Review Inbox would suggest for this
  /// entry, if any. Callers should offer linking that pair instead of
  /// a one-sided convert.
  Future<TransferCandidate?> matchingTransferCandidate() async {
    final existing = _existing;
    if (existing == null) return null;
    return _transactions.findTransferCandidateFor(existing.id);
  }

  /// Soft-deletes the existing entry and records a transfer to/from
  /// [otherAccountId]. Uses the persisted account and direction; amount
  /// and date come from the current form when valid.
  Future<void> convertToTransfer({
    required String otherAccountId,
    String? note,
    String fee = '',
  }) async {
    final existing = _existing;
    if (existing == null) return;

    final amountMinor = Money.tryParseToMinor(state.amount);
    if (amountMinor == null || amountMinor <= 0) {
      emit(
        state.copyWith(
          status: TransactionEntryStatus.invalid,
          errorMessage: 'Enter an amount like 25.50',
        ),
      );
      return;
    }
    if (otherAccountId == existing.accountId) {
      emit(
        state.copyWith(
          status: TransactionEntryStatus.invalid,
          errorMessage: 'Pick a different account',
        ),
      );
      return;
    }
    final trimmedFee = fee.trim();
    int? feeMinor;
    if (trimmedFee.isNotEmpty) {
      feeMinor = Money.tryParseToMinor(trimmedFee);
      if (feeMinor == null || feeMinor < 0) {
        emit(
          state.copyWith(
            status: TransactionEntryStatus.invalid,
            errorMessage: 'Enter a fee like 2.50, or leave it blank',
          ),
        );
        return;
      }
      if (feeMinor == 0) feeMinor = null;
    }

    emit(state.copyWith(status: TransactionEntryStatus.saving));
    try {
      final trimmedNote = note?.trim();
      await _transfers.convertFromTransaction(
        source: existing,
        otherAccountId: otherAccountId,
        amountMinor: amountMinor,
        transactedAt: state.transactedAt,
        note: trimmedNote == null || trimmedNote.isEmpty ? null : trimmedNote,
        feeMinor: feeMinor,
      );
      if (existing.receiptPath != null) {
        await _tryDelete(existing.receiptPath!);
      }
      emit(state.copyWith(status: TransactionEntryStatus.saved));
    } on Object catch (error) {
      emit(
        state.copyWith(
          status: TransactionEntryStatus.failure,
          errorMessage: 'Could not convert: $error',
        ),
      );
    }
  }
}
