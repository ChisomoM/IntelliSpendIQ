import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intellispendiq/data/repositories/account_repository.dart';
import 'package:intellispendiq/data/repositories/category_repository.dart';
import 'package:intellispendiq/data/repositories/raw_capture_repository.dart';
import 'package:intellispendiq/data/repositories/transaction_repository.dart';
import 'package:intellispendiq/domain/models/enums.dart';
import 'package:intellispendiq/domain/models/transaction.dart';
import 'package:intellispendiq/transactions/cubit/cubit.dart';

/// Manual entry and edit screen (Phase 1a) — also the editor used when
/// resolving an item from the Review Inbox.
class TransactionEntryPage extends StatelessWidget {
  const TransactionEntryPage({this.existing, this.rawCaptureId, super.key});

  /// Transaction being edited, or null when adding a new one.
  final Transaction? existing;

  /// Raw capture this entry resolves, when opened from the inbox.
  final String? rawCaptureId;

  static Route<void> route({
    Transaction? existing,
    String? rawCaptureId,
  }) {
    return MaterialPageRoute<void>(
      builder: (_) => TransactionEntryPage(
        existing: existing,
        rawCaptureId: rawCaptureId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => TransactionEntryCubit(
        transactions: context.read<TransactionRepository>(),
        accounts: context.read<AccountRepository>(),
        categories: context.read<CategoryRepository>(),
        rawCaptures: context.read<RawCaptureRepository>(),
        existing: existing,
        rawCaptureId: rawCaptureId,
      )..loadOptionsUnawaited(),
      child: const TransactionEntryView(),
    );
  }
}

class TransactionEntryView extends StatefulWidget {
  const TransactionEntryView({super.key});

  @override
  State<TransactionEntryView> createState() => _TransactionEntryViewState();
}

class _TransactionEntryViewState extends State<TransactionEntryView> {
  late final TextEditingController _amountController;
  late final TextEditingController _merchantController;
  late final TextEditingController _descriptionController;

  @override
  void initState() {
    super.initState();
    final state = context.read<TransactionEntryCubit>().state;
    _amountController = TextEditingController(text: state.amount);
    _merchantController = TextEditingController(text: state.merchant);
    _descriptionController = TextEditingController(text: state.description);
  }

  @override
  void dispose() {
    _amountController.dispose();
    _merchantController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickDate(BuildContext context, DateTime current) async {
    final cubit = context.read<TransactionEntryCubit>();
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

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<TransactionEntryCubit>();
    final isEditing = cubit.isEditing;

    return BlocListener<TransactionEntryCubit, TransactionEntryState>(
      listenWhen: (previous, current) => previous.status != current.status,
      listener: (context, state) {
        if (state.status == TransactionEntryStatus.saved) {
          Navigator.of(context).pop();
        } else if (state.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.errorMessage!)),
          );
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(isEditing ? 'Edit transaction' : 'Add transaction'),
          actions: [
            if (isEditing)
              IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Delete',
                onPressed: cubit.delete,
              ),
          ],
        ),
        body: BlocBuilder<TransactionEntryCubit, TransactionEntryState>(
          builder: (context, state) {
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                SegmentedButton<TxDirection>(
                  segments: const [
                    ButtonSegment(
                      value: TxDirection.debit,
                      label: Text('Spent'),
                      icon: Icon(Icons.arrow_upward),
                    ),
                    ButtonSegment(
                      value: TxDirection.credit,
                      label: Text('Received'),
                      icon: Icon(Icons.arrow_downward),
                    ),
                  ],
                  selected: {state.direction},
                  onSelectionChanged: (values) =>
                      cubit.directionChanged(values.first),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _amountController,
                  decoration: InputDecoration(
                    labelText: 'Amount',
                    prefixText: 'ZMW ',
                    errorText: state.status == TransactionEntryStatus.invalid
                        ? state.errorMessage
                        : null,
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp('[0-9.,]')),
                  ],
                  autofocus: !isEditing,
                  onChanged: cubit.amountChanged,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _merchantController,
                  decoration: const InputDecoration(
                    labelText: 'Merchant or person',
                  ),
                  textCapitalization: TextCapitalization.words,
                  onChanged: cubit.merchantChanged,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue:
                      state.categories.any((c) => c.id == state.categoryId)
                      ? state.categoryId
                      : null,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: [
                    for (final category in state.categories)
                      DropdownMenuItem(
                        value: category.id,
                        child: Text(category.displayName),
                      ),
                  ],
                  onChanged: cubit.categoryChanged,
                ),
                const SizedBox(height: 16),
                if (state.accounts.isNotEmpty)
                  DropdownButtonFormField<String>(
                    initialValue:
                        state.accounts.any((a) => a.id == state.accountId)
                        ? state.accountId
                        : null,
                    decoration: const InputDecoration(labelText: 'Account'),
                    items: [
                      for (final account in state.accounts)
                        DropdownMenuItem(
                          value: account.id,
                          child: Text(account.name),
                        ),
                    ],
                    onChanged: cubit.accountChanged,
                  ),
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.event),
                  title: const Text('Date'),
                  subtitle: Text(
                    state.transactedAt.toString().split('.').first,
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _pickDate(context, state.transactedAt),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(labelText: 'Note'),
                  maxLines: 3,
                  onChanged: cubit.descriptionChanged,
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: state.isSaving ? null : cubit.submit,
                  child: state.isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(isEditing ? 'Save changes' : 'Add transaction'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
