import 'dart:async';
import 'dart:io';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:intellispendiq/core/ids.dart';
import 'package:intellispendiq/core/money.dart';
import 'package:intellispendiq/data/repositories/account_repository.dart';
import 'package:intellispendiq/data/repositories/budget_period_repository.dart';
import 'package:intellispendiq/data/repositories/transaction_repository.dart';
import 'package:intellispendiq/domain/models/account.dart';
import 'package:intellispendiq/domain/models/enums.dart';
import 'package:intellispendiq/domain/models/transaction_draft.dart';
import 'package:intellispendiq/domain/services/receipt_scanner.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'receipt_items_state.dart';

/// Reviews the line items a receipt scan found and saves the checked
/// ones as separate expense transactions — the "split into items" path
/// out of an itemized receipt, as opposed to the single-entry "Scan a
/// receipt" flow that just uses the total.
class ReceiptItemsCubit extends Cubit<ReceiptItemsState> {
  ReceiptItemsCubit({
    required TransactionRepository transactions,
    required AccountRepository accounts,
    required BudgetPeriodRepository budgetPeriods,
    required ReceiptScanResult scan,
    required String sourcePath,
    Future<Directory> Function()? documentsDirectory,
  }) : _transactions = transactions,
       _accounts = accounts,
       _budgetPeriods = budgetPeriods,
       _documentsDirectory =
           documentsDirectory ?? getApplicationDocumentsDirectory,
       super(
         ReceiptItemsState(
           merchant: scan.merchant ?? '',
           transactedAt: scan.transactedAt ?? DateTime.now(),
           items: [
             for (final item in scan.lineItems)
               ReceiptItemDraft(
                 included: true,
                 name: item.name,
                 amount: (item.amountMinor / 100).toStringAsFixed(2),
               ),
           ],
           sourcePath: sourcePath,
         ),
       );

  final TransactionRepository _transactions;
  final AccountRepository _accounts;
  final BudgetPeriodRepository _budgetPeriods;
  final Future<Directory> Function() _documentsDirectory;

  /// Fire-and-forget entry point for widget construction.
  void loadAccountsUnawaited() => unawaited(loadAccounts());

  Future<void> loadAccounts() async {
    final accounts = await _accounts.getAll();
    final defaultAccount = accounts.isEmpty
        ? null
        : accounts.firstWhere(
            (a) => a.isDefault,
            orElse: () => accounts.first,
          );
    emit(
      state.copyWith(
        accounts: accounts,
        accountId: state.accountId ?? defaultAccount?.id,
      ),
    );
  }

  void merchantChanged(String value) => emit(state.copyWith(merchant: value));

  void dateChanged(DateTime value) =>
      emit(state.copyWith(transactedAt: value));

  void accountChanged(String? value) =>
      emit(state.copyWith(accountId: value));

  void itemToggled(int index) => _updateItem(
    index,
    (item) => item.copyWith(included: !item.included),
  );

  void itemNameChanged(int index, String value) =>
      _updateItem(index, (item) => item.copyWith(name: value));

  void itemAmountChanged(int index, String value) =>
      _updateItem(index, (item) => item.copyWith(amount: value));

  void _updateItem(int index, ReceiptItemDraft Function(ReceiptItemDraft) f) {
    final items = [...state.items];
    items[index] = f(items[index]);
    emit(state.copyWith(items: items));
  }

  /// A blank row for an item the scan missed — unchecked by default
  /// (it has no amount yet, so [ReceiptItemsState.canSave] would reject
  /// it anyway) until the user fills it in.
  void addBlankItem() {
    emit(
      state.copyWith(
        items: [
          ...state.items,
          ReceiptItemDraft(included: false, name: '', amount: ''),
        ],
      ),
    );
  }

  void removeItem(int index) {
    final items = [...state.items]..removeAt(index);
    emit(state.copyWith(items: items));
  }

  /// Copies the picked photo into app-local storage (same as manual
  /// entry's receipt attachment) and inserts one confirmed transaction
  /// per checked item, all sharing the same account, date, merchant
  /// and receipt photo.
  Future<void> submit() async {
    if (!state.canSave) {
      emit(
        state.copyWith(
          status: ReceiptItemsStatus.failure,
          errorMessage: 'Check at least one item with a valid amount',
        ),
      );
      return;
    }

    emit(state.copyWith(status: ReceiptItemsStatus.saving));
    try {
      final receiptPath = await _copyReceiptIntoStorage();
      final accountId = state.accountId ?? (await _accounts.getDefault()).id;
      final periodId = (await _budgetPeriods.ensurePeriodContaining(
        state.transactedAt,
      )).id;
      final merchant = state.merchant.trim();

      for (final item in state.items.where((i) => i.included)) {
        final name = item.name.trim();
        await _transactions.insertDraft(
          TransactionDraft(
            amountMinor: Money.tryParseToMinor(item.amount)!,
            direction: TxDirection.debit,
            source: TxSource.manual,
            transactedAt: state.transactedAt,
            merchant: merchant.isEmpty ? null : merchant,
            description: name.isEmpty ? null : name,
            receiptPath: receiptPath,
          ),
          accountId: accountId,
          idempotencyKey: 'manual-item:${Ids.newId()}',
          status: TxStatus.confirmed,
          periodId: periodId,
        );
      }
      emit(state.copyWith(status: ReceiptItemsStatus.saved));
    } on Object catch (error) {
      emit(
        state.copyWith(
          status: ReceiptItemsStatus.failure,
          errorMessage: 'Could not save: $error',
        ),
      );
    }
  }

  Future<String> _copyReceiptIntoStorage() async {
    final documentsDir = await _documentsDirectory();
    final receiptsDir = Directory(p.join(documentsDir.path, 'receipts'));
    await receiptsDir.create(recursive: true);
    final extension = p.extension(state.sourcePath);
    final destination = p.join(receiptsDir.path, '${Ids.newId()}$extension');
    await File(state.sourcePath).copy(destination);
    return destination;
  }
}
