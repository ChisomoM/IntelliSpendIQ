import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:intellispendiq/core/money.dart';
import 'package:intellispendiq/data/repositories/account_repository.dart';
import 'package:intellispendiq/data/repositories/fee_schedule_repository.dart';
import 'package:intellispendiq/data/repositories/transfer_repository.dart';
import 'package:intellispendiq/domain/models/account.dart';
import 'package:intellispendiq/domain/models/transfer.dart';
import 'package:intellispendiq/domain/services/fee_lookup.dart';

part 'transfer_entry_state.dart';

/// Backs editing (and deleting) an existing transfer from Activity.
class TransferEntryCubit extends Cubit<TransferEntryState> {
  TransferEntryCubit({
    required TransferRepository transfers,
    required AccountRepository accounts,
    required Transfer transfer,
    FeeScheduleRepository? fees,
  }) : _transfers = transfers,
       _accounts = accounts,
       _transfer = transfer,
       _fees = fees,
       super(
         TransferEntryState(
           fromAccountId: transfer.fromAccountId,
           toAccountId: transfer.toAccountId,
           amount: (transfer.amountMinor / 100).toStringAsFixed(2),
           note: transfer.note ?? '',
           transactedAt: transfer.transactedAt.toLocal(),
         ),
       );

  final TransferRepository _transfers;
  final AccountRepository _accounts;
  final Transfer _transfer;
  final FeeScheduleRepository? _fees;
  var _feeTouched = false;

  Transfer get transfer => _transfer;

  Future<void> loadOptions() async {
    final accounts = await _accounts.getAll();
    final fee = await _transfers.findFeeForTransfer(_transfer.id);
    var feeText = fee == null ? '' : (fee.amountMinor / 100).toStringAsFixed(2);
    if (fee != null) _feeTouched = true;
    emit(
      state.copyWith(
        accounts: accounts,
        fee: feeText,
      ),
    );
    if (fee == null) await _prefillFee();
  }

  void fromAccountChanged(String? value) {
    if (value == null) return;
    emit(
      state.copyWith(
        fromAccountId: value,
        toAccountId: state.toAccountId == value ? null : state.toAccountId,
      ),
    );
    unawaited(_prefillFee());
  }

  void toAccountChanged(String? value) {
    if (value == null) return;
    emit(state.copyWith(toAccountId: value));
    unawaited(_prefillFee());
  }

  void amountChanged(String value) {
    emit(state.copyWith(amount: value));
    unawaited(_prefillFee());
  }

  void feeChanged(String value) {
    _feeTouched = true;
    emit(state.copyWith(fee: value));
  }

  void noteChanged(String value) => emit(state.copyWith(note: value));

  void dateChanged(DateTime value) => emit(state.copyWith(transactedAt: value));

  Future<void> _prefillFee() async {
    if (_feeTouched) return;
    final fees = _fees;
    final fromId = state.fromAccountId;
    final toId = state.toAccountId;
    if (fees == null || fromId == null || toId == null) return;
    final amountMinor = Money.tryParseToMinor(state.amount);
    if (amountMinor == null || amountMinor <= 0) return;
    Account? from;
    Account? to;
    for (final account in state.accounts) {
      if (account.id == fromId) from = account;
      if (account.id == toId) to = account;
    }
    if (from == null || to == null) return;
    final schedule = await fees.current();
    final feeMinor = FeeLookup.forTransfer(
      schedule: schedule,
      from: from,
      to: to,
      amountMinor: amountMinor,
    );
    final text = FeeLookup.fieldText(feeMinor);
    if (state.fee != text) emit(state.copyWith(fee: text));
  }

  Future<void> submit() async {
    final amountMinor = Money.tryParseToMinor(state.amount);
    if (amountMinor == null || amountMinor <= 0) {
      emit(
        state.copyWith(
          status: TransferEntryStatus.invalid,
          errorMessage: 'Enter an amount like 25.50',
        ),
      );
      return;
    }
    final fromId = state.fromAccountId;
    final toId = state.toAccountId;
    if (fromId == null || toId == null) {
      emit(
        state.copyWith(
          status: TransferEntryStatus.invalid,
          errorMessage: 'Pick both accounts',
        ),
      );
      return;
    }
    if (fromId == toId) {
      emit(
        state.copyWith(
          status: TransferEntryStatus.invalid,
          errorMessage: 'Pick two different accounts',
        ),
      );
      return;
    }

    final trimmedFee = state.fee.trim();
    int? feeMinor;
    var clearFee = false;
    if (trimmedFee.isEmpty) {
      clearFee = true;
    } else {
      feeMinor = Money.tryParseToMinor(trimmedFee);
      if (feeMinor == null || feeMinor < 0) {
        emit(
          state.copyWith(
            status: TransferEntryStatus.invalid,
            errorMessage: 'Enter a fee like 2.50, or leave it blank',
          ),
        );
        return;
      }
      if (feeMinor == 0) {
        clearFee = true;
        feeMinor = null;
      }
    }

    emit(state.copyWith(status: TransferEntryStatus.saving));
    try {
      final note = state.note.trim();
      await _transfers.updateFields(
        _transfer.id,
        fromAccountId: fromId,
        toAccountId: toId,
        amountMinor: amountMinor,
        transactedAt: state.transactedAt,
        note: note.isEmpty ? null : note,
        clearNote: note.isEmpty,
        feeMinor: feeMinor,
        clearFee: clearFee,
      );
      emit(state.copyWith(status: TransferEntryStatus.saved));
    } on Object catch (error) {
      emit(
        state.copyWith(
          status: TransferEntryStatus.failure,
          errorMessage: 'Could not save: $error',
        ),
      );
    }
  }

  Future<void> delete() async {
    await _transfers.softDelete(_transfer.id);
    emit(state.copyWith(status: TransferEntryStatus.deleted));
  }
}
