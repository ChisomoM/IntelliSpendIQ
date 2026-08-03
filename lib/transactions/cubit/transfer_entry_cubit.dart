import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:intellispendiq/core/money.dart';
import 'package:intellispendiq/data/repositories/account_repository.dart';
import 'package:intellispendiq/data/repositories/transfer_repository.dart';
import 'package:intellispendiq/domain/models/account.dart';
import 'package:intellispendiq/domain/models/transfer.dart';

part 'transfer_entry_state.dart';

/// Backs editing (and deleting) an existing transfer from Activity.
class TransferEntryCubit extends Cubit<TransferEntryState> {
  TransferEntryCubit({
    required TransferRepository transfers,
    required AccountRepository accounts,
    required Transfer transfer,
  }) : _transfers = transfers,
       _accounts = accounts,
       _transfer = transfer,
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

  Transfer get transfer => _transfer;

  Future<void> loadOptions() async {
    final accounts = await _accounts.getAll();
    final fee = await _transfers.findFeeForTransfer(_transfer.id);
    emit(
      state.copyWith(
        accounts: accounts,
        fee: fee == null ? '' : (fee.amountMinor / 100).toStringAsFixed(2),
      ),
    );
  }

  void fromAccountChanged(String? value) {
    if (value == null) return;
    emit(
      state.copyWith(
        fromAccountId: value,
        toAccountId: state.toAccountId == value ? null : state.toAccountId,
      ),
    );
  }

  void toAccountChanged(String? value) {
    if (value == null) return;
    emit(state.copyWith(toAccountId: value));
  }

  void amountChanged(String value) => emit(state.copyWith(amount: value));

  void feeChanged(String value) => emit(state.copyWith(fee: value));

  void noteChanged(String value) => emit(state.copyWith(note: value));

  void dateChanged(DateTime value) => emit(state.copyWith(transactedAt: value));

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
