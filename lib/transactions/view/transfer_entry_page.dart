import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intellispendiq/data/repositories/account_repository.dart';
import 'package:intellispendiq/data/repositories/transfer_repository.dart';
import 'package:intellispendiq/design/design.dart';
import 'package:intellispendiq/domain/models/transfer.dart';
import 'package:intellispendiq/transactions/cubit/transfer_entry_cubit.dart';
import 'package:intl/intl.dart';

/// Edit or delete a transfer from the Activity feed.
class TransferEntryPage extends StatelessWidget {
  const TransferEntryPage({required this.transfer, super.key});

  final Transfer transfer;

  static Route<TransferEntryResult?> route(Transfer transfer) {
    return MaterialPageRoute<TransferEntryResult?>(
      builder: (_) => TransferEntryPage(transfer: transfer),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) {
        final cubit = TransferEntryCubit(
          transfers: context.read<TransferRepository>(),
          accounts: context.read<AccountRepository>(),
          transfer: transfer,
        );
        unawaited(cubit.loadOptions());
        return cubit;
      },
      child: const TransferEntryView(),
    );
  }
}

/// What happened on the transfer editor — callers use this for undo.
enum TransferEntryResult { saved, deleted }

class TransferEntryView extends StatefulWidget {
  const TransferEntryView({super.key});

  @override
  State<TransferEntryView> createState() => _TransferEntryViewState();
}

class _TransferEntryViewState extends State<TransferEntryView> {
  late final TextEditingController _amountController;
  late final TextEditingController _feeController;
  late final TextEditingController _noteController;

  @override
  void initState() {
    super.initState();
    final state = context.read<TransferEntryCubit>().state;
    _amountController = TextEditingController(text: state.amount);
    _feeController = TextEditingController(text: state.fee);
    _noteController = TextEditingController(text: state.note);
  }

  @override
  void dispose() {
    _amountController.dispose();
    _feeController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickDate(BuildContext context) async {
    final cubit = context.read<TransferEntryCubit>();
    final current = cubit.state.transactedAt;
    final date = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (date == null || !context.mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
    );
    cubit.dateChanged(
      DateTime(
        date.year,
        date.month,
        date.day,
        time?.hour ?? current.hour,
        time?.minute ?? current.minute,
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final cubit = context.read<TransferEntryCubit>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete this transfer?'),
        content: const Text(
          'It will disappear from Activity. You can undo for a moment.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (!(confirmed ?? false) || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final undoDuration = Motion.of(context, Motion.undoHold);
    final transfers = context.read<TransferRepository>();
    final id = cubit.transfer.id;
    await cubit.delete();
    messenger.showSnackBar(
      SnackBar(
        content: const Text('Transfer deleted'),
        duration: undoDuration,
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            unawaited(transfers.undelete(id));
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<TransferEntryCubit>();

    return BlocListener<TransferEntryCubit, TransferEntryState>(
      listenWhen: (previous, current) =>
          previous.status != current.status ||
          (previous.fee != current.fee && _feeController.text != current.fee),
      listener: (context, state) {
        if (_feeController.text != state.fee) {
          _feeController.text = state.fee;
        }
        if (state.status == TransferEntryStatus.saved) {
          Navigator.of(context).pop(TransferEntryResult.saved);
        } else if (state.status == TransferEntryStatus.deleted) {
          Navigator.of(context).pop(TransferEntryResult.deleted);
        } else if (state.status == TransferEntryStatus.failure &&
            state.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.errorMessage!)),
          );
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Edit transfer'),
          actions: [
            IconButton(
              icon: AppIcon(AppIcons.delete),
              tooltip: 'Delete',
              onPressed: () => _confirmDelete(context),
            ),
          ],
        ),
        body: BlocBuilder<TransferEntryCubit, TransferEntryState>(
          builder: (context, state) {
            final colors = Theme.of(context).colorScheme;
            final accounts = state.accounts;

            return ListView(
              padding: const EdgeInsets.fromLTRB(
                Space.gutter,
                Space.x2,
                Space.gutter,
                Space.x3,
              ),
              children: [
                Text(
                  'Money moved between your own accounts — this never '
                  'counts as spend or income.',
                  style: AppTypography.metadata(color: colors.onSurfaceVariant),
                ),
                const SizedBox(height: Space.x2),
                if (accounts.length >= 2) ...[
                  DropdownButtonFormField<String>(
                    initialValue: accounts.any((a) => a.id == state.fromAccountId)
                        ? state.fromAccountId
                        : null,
                    decoration: const InputDecoration(labelText: 'From'),
                    items: [
                      for (final account in accounts)
                        DropdownMenuItem(
                          value: account.id,
                          child: Text(account.name),
                        ),
                    ],
                    onChanged: cubit.fromAccountChanged,
                  ),
                  const SizedBox(height: Space.x2),
                  DropdownButtonFormField<String>(
                    initialValue: accounts.any((a) => a.id == state.toAccountId)
                        ? state.toAccountId
                        : null,
                    decoration: const InputDecoration(labelText: 'To'),
                    items: [
                      for (final account in accounts)
                        if (account.id != state.fromAccountId)
                          DropdownMenuItem(
                            value: account.id,
                            child: Text(account.name),
                          ),
                    ],
                    onChanged: cubit.toAccountChanged,
                  ),
                  const SizedBox(height: Space.x2),
                ],
                AmountField(
                  controller: _amountController,
                  errorText: state.status == TransferEntryStatus.invalid
                      ? state.errorMessage
                      : null,
                  onChanged: cubit.amountChanged,
                ),
                const SizedBox(height: Space.x2),
                AmountField(
                  controller: _feeController,
                  label: 'Fee (optional)',
                  onChanged: cubit.feeChanged,
                ),
                const SizedBox(height: Space.x2),
                AppListRow(
                  title: const Text('Date'),
                  subtitle: Text(
                    DateFormat('d MMM yyyy, HH:mm').format(state.transactedAt),
                  ),
                  trailing: AppIcon(
                    AppIcons.chevronRight,
                    size: 18,
                    color: colors.onSurfaceVariant,
                  ),
                  onTap: () => _pickDate(context),
                ),
                const SizedBox(height: Space.x2),
                AppTextField(
                  controller: _noteController,
                  label: 'Note (optional)',
                  onChanged: cubit.noteChanged,
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
                      : const Text('Save changes'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
