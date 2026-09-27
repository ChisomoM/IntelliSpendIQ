import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intellispendiq/data/repositories/account_repository.dart';
import 'package:intellispendiq/data/repositories/budget_period_repository.dart';
import 'package:intellispendiq/data/repositories/transaction_repository.dart';
import 'package:intellispendiq/design/design.dart';
import 'package:intellispendiq/domain/services/receipt_scanner.dart';
import 'package:intellispendiq/receipts/cubit/receipt_items_cubit.dart';
import 'package:intl/intl.dart';

/// Review screen for an itemized receipt scan — a checklist of the
/// priced lines OCR found (name + amount, all editable), pre-checked,
/// saved as one expense transaction per checked item on confirm.
class ReceiptItemsPage extends StatelessWidget {
  const ReceiptItemsPage({
    required this.scan,
    required this.sourcePath,
    super.key,
  });

  final ReceiptScanResult scan;
  final String sourcePath;

  /// Pops with the number of entries saved (0 or null if the user
  /// backed out without saving).
  static Route<int?> route({
    required ReceiptScanResult scan,
    required String sourcePath,
  }) {
    return MaterialPageRoute<int?>(
      builder: (_) => ReceiptItemsPage(scan: scan, sourcePath: sourcePath),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ReceiptItemsCubit(
        transactions: context.read<TransactionRepository>(),
        accounts: context.read<AccountRepository>(),
        budgetPeriods: context.read<BudgetPeriodRepository>(),
        scan: scan,
        sourcePath: sourcePath,
      )..loadAccountsUnawaited(),
      child: const _ReceiptItemsView(),
    );
  }
}

class _ReceiptItemsView extends StatefulWidget {
  const _ReceiptItemsView();

  @override
  State<_ReceiptItemsView> createState() => _ReceiptItemsViewState();
}

class _ReceiptItemsViewState extends State<_ReceiptItemsView> {
  late final TextEditingController _merchantController;

  static final _dateFormat = DateFormat('d MMM yyyy');

  @override
  void initState() {
    super.initState();
    _merchantController = TextEditingController(
      text: context.read<ReceiptItemsCubit>().state.merchant,
    );
  }

  @override
  void dispose() {
    _merchantController.dispose();
    super.dispose();
  }

  Future<void> _pickDate(BuildContext context, DateTime current) async {
    final cubit = context.read<ReceiptItemsCubit>();
    final date = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (date == null) return;
    cubit.dateChanged(DateTime(date.year, date.month, date.day));
  }

  /// Confirms before throwing away a reviewed-but-unsaved item list —
  /// same protection Add Entry gives a part-written manual entry.
  Future<bool> _confirmDiscard(BuildContext context) async {
    final state = context.read<ReceiptItemsCubit>().state;
    if (state.includedCount == 0 || state.status == ReceiptItemsStatus.saved) {
      return true;
    }

    final discard = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Discard these entries?'),
        content: Text(
          '${state.includedCount} '
          '${state.includedCount == 1 ? 'item' : 'items'} '
          "won't be saved.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep editing'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    return discard ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ReceiptItemsCubit>();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        if (await _confirmDiscard(context)) navigator.pop();
      },
      child: BlocListener<ReceiptItemsCubit, ReceiptItemsState>(
        listenWhen: (previous, current) => previous.status != current.status,
        listener: (context, state) {
          if (state.status == ReceiptItemsStatus.saved) {
            Navigator.of(context).pop(state.includedCount);
          } else if (state.status == ReceiptItemsStatus.failure &&
              state.errorMessage != null) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(state.errorMessage!)));
          }
        },
        child: Scaffold(
          appBar: AppBar(title: const Text('Split receipt into entries')),
          body: BlocBuilder<ReceiptItemsCubit, ReceiptItemsState>(
            builder: (context, state) {
              return ListView(
                padding: const EdgeInsets.fromLTRB(
                  Space.gutter,
                  Space.x2,
                  Space.gutter,
                  Space.x3,
                ),
                children: [
                  ClipRRect(
                    borderRadius: Radii.chipRadius,
                    child: Image.file(
                      File(state.sourcePath),
                      height: 120,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      errorBuilder: (_, _, _) => Container(
                        height: 120,
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHigh,
                        alignment: Alignment.center,
                        child: AppIcon(AppIcons.unknown, size: 32),
                      ),
                    ),
                  ),
                  const SizedBox(height: Space.x2),
                  AppTextField(
                    controller: _merchantController,
                    label: 'Merchant or store',
                    textCapitalization: TextCapitalization.words,
                    onChanged: cubit.merchantChanged,
                  ),
                  const SizedBox(height: Space.x2),
                  Row(
                    children: [
                      if (state.accounts.isNotEmpty)
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue:
                                state.accounts.any(
                                  (a) => a.id == state.accountId,
                                )
                                ? state.accountId
                                : null,
                            decoration: const InputDecoration(
                              labelText: 'Account',
                            ),
                            items: [
                              for (final account in state.accounts)
                                DropdownMenuItem(
                                  value: account.id,
                                  child: Text(account.name),
                                ),
                            ],
                            onChanged: cubit.accountChanged,
                          ),
                        ),
                      const SizedBox(width: Space.x2),
                      ActionChip(
                        avatar: AppIcon(AppIcons.calendar, size: 16),
                        label: Text(_dateFormat.format(state.transactedAt)),
                        onPressed: () => _pickDate(context, state.transactedAt),
                      ),
                    ],
                  ),
                  const SizedBox(height: Space.x3),
                  Text(
                    'ITEMS',
                    style: AppTypography.chipOverline(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: Space.x1),
                  for (var i = 0; i < state.items.length; i++)
                    _ItemRow(
                      key: ValueKey(state.items[i].id),
                      item: state.items[i],
                      onToggled: () => cubit.itemToggled(i),
                      onNameChanged: (value) => cubit.itemNameChanged(i, value),
                      onAmountChanged: (value) =>
                          cubit.itemAmountChanged(i, value),
                      onRemoved: () => cubit.removeItem(i),
                    ),
                  const SizedBox(height: Space.x1),
                  AppButton.tertiary(
                    label: 'Add a missed item',
                    icon: AppIcon(AppIcons.add, size: 18),
                    onPressed: cubit.addBlankItem,
                  ),
                  const SizedBox(height: Space.x3),
                  FilledButton(
                    onPressed: state.isSaving || !state.canSave
                        ? null
                        : cubit.submit,
                    child: state.isSaving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            state.includedCount == 0
                                ? 'Add entries'
                                : 'Add ${state.includedCount} '
                                      '${state.includedCount == 1 ? 'entry' : 'entries'}',
                          ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ItemRow extends StatefulWidget {
  const _ItemRow({
    required super.key,
    required this.item,
    required this.onToggled,
    required this.onNameChanged,
    required this.onAmountChanged,
    required this.onRemoved,
  });

  final ReceiptItemDraft item;
  final VoidCallback onToggled;
  final ValueChanged<String> onNameChanged;
  final ValueChanged<String> onAmountChanged;
  final VoidCallback onRemoved;

  @override
  State<_ItemRow> createState() => _ItemRowState();
}

class _ItemRowState extends State<_ItemRow> {
  late final TextEditingController _nameController;
  late final TextEditingController _amountController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.item.name);
    _amountController = TextEditingController(text: widget.item.amount);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Space.x1 / 2),
      child: Row(
        children: [
          Checkbox(
            value: widget.item.included,
            onChanged: (_) => widget.onToggled(),
          ),
          Expanded(
            flex: 3,
            child: AppTextField(
              controller: _nameController,
              label: 'Item',
              onChanged: widget.onNameChanged,
            ),
          ),
          const SizedBox(width: Space.x1),
          Expanded(
            flex: 2,
            child: AmountField(
              controller: _amountController,
              onChanged: widget.onAmountChanged,
            ),
          ),
          IconButton(
            icon: AppIcon(AppIcons.delete, size: 20),
            tooltip: 'Remove item',
            onPressed: widget.onRemoved,
          ),
        ],
      ),
    );
  }
}
