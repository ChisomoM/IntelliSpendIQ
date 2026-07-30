import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intellispendiq/categories/categories.dart';
import 'package:intellispendiq/data/repositories/account_repository.dart';
import 'package:intellispendiq/data/repositories/category_repository.dart';
import 'package:intellispendiq/data/repositories/label_repository.dart';
import 'package:intellispendiq/data/repositories/payee_repository.dart';
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
        payees: context.read<PayeeRepository>(),
        labels: context.read<LabelRepository>(),
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

  Future<void> _addCategory(BuildContext context) async {
    final cubit = context.read<TransactionEntryCubit>();
    final direction = cubit.state.direction;
    final id = await Navigator.of(context).push<String?>(
      CategoryEditorPage.route(
        initialType: direction == TxDirection.credit
            ? CategoryType.income
            : CategoryType.expense,
      ),
    );
    if (id != null && context.mounted) {
      await cubit.loadOptions();
      cubit.categoryChanged(id);
    }
  }

  Future<void> _addPayee(BuildContext context) async {
    final cubit = context.read<TransactionEntryCubit>();
    final name = await _promptForName(context, title: 'Add payee');
    if (name != null && name.trim().isNotEmpty) {
      await cubit.payeeAdded(name);
    }
  }

  Future<void> _addLabel(BuildContext context) async {
    final cubit = context.read<TransactionEntryCubit>();
    final name = await _promptForName(context, title: 'Add label');
    if (name != null && name.trim().isNotEmpty) {
      await cubit.labelAdded(name);
    }
  }

  Future<String?> _promptForName(
    BuildContext context, {
    required String title,
  }) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          onSubmitted: (value) => Navigator.of(dialogContext).pop(value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text),
            child: const Text('Add'),
          ),
        ],
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
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue:
                            state.categories.any(
                              (c) => c.id == state.categoryId,
                            )
                            ? state.categoryId
                            : null,
                        decoration: const InputDecoration(
                          labelText: 'Category',
                        ),
                        items: [
                          for (final category in state.categories)
                            DropdownMenuItem(
                              value: category.id,
                              child: Text(category.displayName),
                            ),
                        ],
                        onChanged: cubit.categoryChanged,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      tooltip: 'Add category',
                      onPressed: () => _addCategory(context),
                    ),
                  ],
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
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String?>(
                        initialValue:
                            state.payees.any(
                              (p) => p.id == state.payeeId,
                            )
                            ? state.payeeId
                            : null,
                        decoration: const InputDecoration(
                          labelText: 'Payee (optional)',
                        ),
                        items: [
                          const DropdownMenuItem(child: Text('None')),
                          for (final payee in state.payees)
                            DropdownMenuItem(
                              value: payee.id,
                              child: Text(payee.name),
                            ),
                        ],
                        onChanged: cubit.payeeChanged,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      tooltip: 'Add payee',
                      onPressed: () => _addPayee(context),
                    ),
                  ],
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
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Mark as paid'),
                  subtitle: state.isPaid
                      ? null
                      : const Text(
                          "Recorded as planned — won't count toward totals "
                          'until paid',
                        ),
                  value: state.isPaid,
                  onChanged: cubit.paidChanged,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(labelText: 'Note'),
                  maxLines: 3,
                  onChanged: cubit.descriptionChanged,
                ),
                const SizedBox(height: 16),
                Text('Labels', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final label in state.labels)
                      FilterChip(
                        label: Text(label.name),
                        selected: state.labelIds.contains(label.id),
                        onSelected: (_) => cubit.labelToggled(label.id),
                      ),
                    ActionChip(
                      avatar: const Icon(Icons.add, size: 18),
                      label: const Text('Add label'),
                      onPressed: () => _addLabel(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _ReceiptField(receiptPath: state.receiptPath),
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

/// Attaches, previews, or removes a receipt photo — snapped with the
/// camera or picked from the gallery. The chosen file is copied into
/// app-local storage by the cubit, so it survives the user deleting
/// it from wherever it was picked.
class _ReceiptField extends StatelessWidget {
  const _ReceiptField({required this.receiptPath});

  final String? receiptPath;

  Future<void> _pick(BuildContext context) async {
    final cubit = context.read<TransactionEntryCubit>();
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take photo'),
              onTap: () => Navigator.of(sheetContext).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.of(sheetContext).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    String? path;
    if (source == ImageSource.camera) {
      final photo = await ImagePicker().pickImage(source: ImageSource.camera);
      path = photo?.path;
    } else {
      final result = await FilePicker.pickFiles(type: FileType.image);
      path = result?.files.single.path;
    }
    if (path != null) await cubit.attachReceipt(path);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (receiptPath == null) {
      return OutlinedButton.icon(
        onPressed: () => _pick(context),
        icon: const Icon(Icons.add_a_photo_outlined),
        label: const Text('Attach a receipt'),
      );
    }

    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.file(
            File(receiptPath!),
            width: 56,
            height: 56,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => Container(
              width: 56,
              height: 56,
              color: theme.colorScheme.surfaceContainerHighest,
              child: const Icon(Icons.broken_image_outlined),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text('Receipt attached', style: theme.textTheme.bodyMedium),
        ),
        TextButton(
          onPressed: () => _pick(context),
          child: const Text('Replace'),
        ),
        IconButton(
          icon: const Icon(Icons.delete_outline),
          tooltip: 'Remove receipt',
          onPressed: () =>
              context.read<TransactionEntryCubit>().removeReceipt(),
        ),
      ],
    );
  }
}
