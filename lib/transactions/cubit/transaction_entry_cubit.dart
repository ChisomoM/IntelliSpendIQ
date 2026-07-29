import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:intellispendiq/core/ids.dart';
import 'package:intellispendiq/core/money.dart';
import 'package:intellispendiq/core/time.dart';
import 'package:intellispendiq/data/db/app_database.dart';
import 'package:intellispendiq/data/repositories/account_repository.dart';
import 'package:intellispendiq/data/repositories/category_repository.dart';
import 'package:intellispendiq/data/repositories/raw_capture_repository.dart';
import 'package:intellispendiq/data/repositories/transaction_repository.dart';
import 'package:intellispendiq/domain/models/enums.dart';
import 'package:intellispendiq/domain/models/transaction_draft.dart';

part 'transaction_entry_state.dart';

/// Backs manual entry and editing, including the "enter manually" path
/// out of the Review Inbox.
class TransactionEntryCubit extends Cubit<TransactionEntryState> {
  TransactionEntryCubit({
    required TransactionRepository transactions,
    required AccountRepository accounts,
    required CategoryRepository categories,
    required RawCaptureRepository rawCaptures,
    TransactionRow? existing,
    String? rawCaptureId,
  }) : _transactions = transactions,
       _accounts = accounts,
       _categories = categories,
       _rawCaptures = rawCaptures,
       _existing = existing,
       _rawCaptureId = rawCaptureId,
       super(
         existing == null
             ? TransactionEntryState(transactedAt: DateTime.now())
             : TransactionEntryState(
                 amount: (existing.amountMinor / 100).toStringAsFixed(2),
                 merchant: existing.merchant ?? '',
                 description: existing.description ?? '',
                 direction: TxDirection.fromName(existing.direction),
                 categoryId: existing.categoryId,
                 accountId: existing.accountId,
                 transactedAt: Iso.toDateTime(existing.transactedAt).toLocal(),
               ),
       );

  final TransactionRepository _transactions;
  final AccountRepository _accounts;
  final CategoryRepository _categories;
  final RawCaptureRepository _rawCaptures;
  final TransactionRow? _existing;
  final String? _rawCaptureId;

  bool get isEditing => _existing != null;

  /// Fire-and-forget entry point for widget construction.
  void loadOptionsUnawaited() => unawaited(loadOptions());

  /// Loads the pickers' options and defaults the account.
  Future<void> loadOptions() async {
    final categories = await _categories.getAll();
    final accounts = await _accounts.getAll();
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
        accountId: state.accountId ?? defaultAccount?.id,
      ),
    );
  }

  void amountChanged(String value) => emit(state.copyWith(amount: value));

  void merchantChanged(String value) => emit(state.copyWith(merchant: value));

  void descriptionChanged(String value) =>
      emit(state.copyWith(description: value));

  void directionChanged(TxDirection value) =>
      emit(state.copyWith(direction: value));

  void categoryChanged(String? value) =>
      emit(state.copyWith(categoryId: value));

  void accountChanged(String? value) => emit(state.copyWith(accountId: value));

  void dateChanged(DateTime value) => emit(state.copyWith(transactedAt: value));

  /// Validates and writes. Editing marks the row confirmed, because a
  /// human has now looked at it.
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

    try {
      if (isEditing) {
        await _transactions.updateFields(
          _existing!.id,
          amountMinor: amountMinor,
          merchant: merchant.isEmpty ? null : merchant,
          description: description.isEmpty ? null : description,
          categoryId: state.categoryId,
          transactedAt: state.transactedAt,
          status: TxStatus.confirmed,
        );
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
          ),
          accountId: accountId,
          idempotencyKey: 'manual:${Ids.newId()}',
          status: TxStatus.confirmed,
          rawCaptureId: _rawCaptureId,
        );
        if (_rawCaptureId != null) {
          await _rawCaptures.resolveManually(
            _rawCaptureId,
            transactionId: transaction.id,
          );
        }
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
    if (!isEditing) return;
    await _transactions.softDelete(_existing!.id);
    emit(state.copyWith(status: TransactionEntryStatus.saved));
  }
}
