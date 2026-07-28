import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intellispendiq/app/app.dart';
import 'package:intellispendiq/core/ids.dart';
import 'package:intellispendiq/core/money.dart';
import 'package:intellispendiq/core/time.dart';
import 'package:intellispendiq/data/db/app_database.dart';
import 'package:intellispendiq/domain/models/enums.dart';
import 'package:intellispendiq/domain/models/transaction_draft.dart';

/// Manual entry and edit screen (Phase 1a) — also the editor used when
/// confirming an item from the Review Inbox.
class TransactionEntryPage extends StatefulWidget {
  const TransactionEntryPage({this.existing, this.rawCaptureId, super.key});

  /// Transaction being edited, or null when adding a new one.
  final TransactionRow? existing;

  /// Raw capture this entry resolves, when opened from the inbox.
  final String? rawCaptureId;

  @override
  State<TransactionEntryPage> createState() => _TransactionEntryPageState();
}

class _TransactionEntryPageState extends State<TransactionEntryPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountController;
  late final TextEditingController _merchantController;
  late final TextEditingController _descriptionController;

  TxDirection _direction = TxDirection.debit;
  DateTime _transactedAt = DateTime.now();
  String? _categoryId;
  String? _accountId;
  bool _saving = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _amountController = TextEditingController(
      text: existing == null
          ? ''
          : (existing.amountMinor / 100).toStringAsFixed(2),
    );
    _merchantController = TextEditingController(text: existing?.merchant ?? '');
    _descriptionController = TextEditingController(
      text: existing?.description ?? '',
    );
    if (existing != null) {
      _direction = TxDirection.fromName(existing.direction);
      _transactedAt = Iso.toDateTime(existing.transactedAt).toLocal();
      _categoryId = existing.categoryId;
      _accountId = existing.accountId;
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _merchantController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);

    final services = AppScope.of(context);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final amountMinor = Money.tryParseToMinor(_amountController.text)!;
    final merchant = _merchantController.text.trim();
    final description = _descriptionController.text.trim();

    try {
      if (_isEditing) {
        await services.transactions.updateFields(
          widget.existing!.id,
          amountMinor: amountMinor,
          merchant: merchant.isEmpty ? null : merchant,
          description: description.isEmpty ? null : description,
          categoryId: _categoryId,
          transactedAt: _transactedAt,
          // A human has now looked at it, so it is confirmed.
          status: TxStatus.confirmed,
        );
      } else {
        final accountId =
            _accountId ?? (await services.accounts.getDefault()).id;
        final transaction = await services.transactions.insertDraft(
          TransactionDraft(
            amountMinor: amountMinor,
            direction: _direction,
            source: TxSource.manual,
            transactedAt: _transactedAt,
            merchant: merchant.isEmpty ? null : merchant,
            description: description.isEmpty ? null : description,
            categoryId: _categoryId,
            confidence: 1,
          ),
          accountId: accountId,
          idempotencyKey: 'manual:${Ids.newId()}',
          status: TxStatus.confirmed,
          rawCaptureId: widget.rawCaptureId,
        );
        if (widget.rawCaptureId != null) {
          await services.rawCaptures.resolveManually(
            widget.rawCaptureId!,
            transactionId: transaction.id,
          );
        }
      }
      navigator.pop(true);
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(
        SnackBar(content: Text('Could not save: $error')),
      );
    }
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _transactedAt,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_transactedAt),
    );
    setState(() {
      _transactedAt = DateTime(
        date.year,
        date.month,
        date.day,
        time?.hour ?? _transactedAt.hour,
        time?.minute ?? _transactedAt.minute,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit transaction' : 'Add transaction'),
        actions: [
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Delete',
              onPressed: () async {
                final navigator = Navigator.of(context);
                await services.transactions.softDelete(widget.existing!.id);
                navigator.pop(true);
              },
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
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
              selected: {_direction},
              onSelectionChanged: (values) =>
                  setState(() => _direction = values.first),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _amountController,
              decoration: const InputDecoration(
                labelText: 'Amount',
                prefixText: 'ZMW ',
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp('[0-9.,]')),
              ],
              autofocus: !_isEditing,
              validator: (value) {
                final minor = Money.tryParseToMinor(value ?? '');
                if (minor == null) return 'Enter an amount like 25.50';
                if (minor <= 0) return 'Amount must be greater than zero';
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _merchantController,
              decoration: const InputDecoration(
                labelText: 'Merchant or person',
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 16),
            StreamBuilder<List<CategoryRow>>(
              stream: services.categories.watchAll(),
              builder: (context, snapshot) {
                final categories = snapshot.data ?? const <CategoryRow>[];
                return DropdownButtonFormField<String>(
                  initialValue: categories.any((c) => c.id == _categoryId)
                      ? _categoryId
                      : null,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: [
                    for (final category in categories)
                      DropdownMenuItem(
                        value: category.id,
                        child: Text('${category.icon ?? ''} ${category.name}'),
                      ),
                  ],
                  onChanged: (value) => setState(() => _categoryId = value),
                );
              },
            ),
            const SizedBox(height: 16),
            StreamBuilder<List<AccountRow>>(
              stream: services.accounts.watchAll(),
              builder: (context, snapshot) {
                final accounts = snapshot.data ?? const <AccountRow>[];
                if (accounts.isEmpty) return const SizedBox.shrink();
                final selected = accounts.any((a) => a.id == _accountId)
                    ? _accountId
                    : accounts
                          .firstWhere(
                            (a) => a.isDefault,
                            orElse: () => accounts.first,
                          )
                          .id;
                return DropdownButtonFormField<String>(
                  initialValue: selected,
                  decoration: const InputDecoration(labelText: 'Account'),
                  items: [
                    for (final account in accounts)
                      DropdownMenuItem(
                        value: account.id,
                        child: Text(account.name),
                      ),
                  ],
                  onChanged: (value) => setState(() => _accountId = value),
                );
              },
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event),
              title: const Text('Date'),
              subtitle: Text(
                _transactedAt.toLocal().toString().split('.').first,
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: _pickDate,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(labelText: 'Note'),
              maxLines: 3,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(_isEditing ? 'Save changes' : 'Add transaction'),
            ),
          ],
        ),
      ),
    );
  }
}
