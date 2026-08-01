import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intellispendiq/categories/categories.dart';
import 'package:intellispendiq/data/repositories/account_repository.dart';
import 'package:intellispendiq/data/repositories/category_repository.dart';
import 'package:intellispendiq/data/repositories/label_repository.dart';
import 'package:intellispendiq/data/repositories/payee_repository.dart';
import 'package:intellispendiq/data/repositories/raw_capture_repository.dart';
import 'package:intellispendiq/data/repositories/transaction_repository.dart';
import 'package:intellispendiq/design/design.dart';
import 'package:intellispendiq/domain/models/category.dart';
import 'package:intellispendiq/domain/models/enums.dart';
import 'package:intellispendiq/domain/models/transaction.dart';
import 'package:intellispendiq/domain/services/merchant_categorizer.dart';
import 'package:intellispendiq/transactions/cubit/cubit.dart';
// Imported directly rather than through the widgets barrel: that
// barrel also exports the tile, which imports this file back.
import 'package:intellispendiq/transactions/widgets/raw_source_sheet.dart';
import 'package:intl/intl.dart';

/// Manual entry and edit — also the editor used when resolving an item
/// from the Review Inbox.
///
/// Laid out amount-first: the amount is the headline, category is a
/// chip row rather than a dropdown, and the date defaults to now with
/// Today/Yesterday shortcuts, so the common case is
/// "type an amount, tap a category, save". Everything that is usually
/// left alone — account, payee, note, labels, receipt — lives behind
/// "More details" instead of padding the first screen.
class TransactionEntryPage extends StatelessWidget {
  const TransactionEntryPage({this.existing, this.rawCaptureId, super.key});

  /// Transaction being edited, or null when adding a new one.
  final Transaction? existing;

  /// Raw capture this entry resolves, when opened from the inbox.
  final String? rawCaptureId;

  static Route<void> route({Transaction? existing, String? rawCaptureId}) {
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
        categorizer: context.read<MerchantCategorizer>(),
        existing: existing,
        rawCaptureId: rawCaptureId,
      )..loadOptionsUnawaited(),
      child: TransactionEntryView(existing: existing),
    );
  }
}

class TransactionEntryView extends StatefulWidget {
  const TransactionEntryView({this.existing, super.key});

  final Transaction? existing;

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

  /// Only reachable behind "Pick a date" now. The Today/Yesterday
  /// shortcuts cover the overwhelming majority of manual entries in
  /// one tap, where this used to be two chained modals every time.
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
    if (id == null) return;
    await cubit.loadOptions();
    cubit.categoryChanged(id);
  }

  /// Deleting used to fire straight off the app-bar icon with nothing
  /// in between, on a screen where that icon sits next to Save.
  Future<void> _confirmDelete(BuildContext context) async {
    final cubit = context.read<TransactionEntryCubit>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete this entry?'),
        content: const Text('This cannot be undone.'),
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
    if (confirmed ?? false) await cubit.delete();
  }

  /// Confirms before throwing away a part-written entry.
  Future<bool> _confirmDiscard(BuildContext context) async {
    final state = context.read<TransactionEntryCubit>().state;
    final hasContent =
        state.amount.trim().isNotEmpty || state.merchant.trim().isNotEmpty;
    if (!hasContent || state.status == TransactionEntryStatus.saved) {
      return true;
    }

    final discard = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Discard this entry?'),
        content: const Text('What you have typed will not be saved.'),
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
    final cubit = context.read<TransactionEntryCubit>();
    final isEditing = cubit.isEditing;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        if (await _confirmDiscard(context)) navigator.pop();
      },
      child: BlocListener<TransactionEntryCubit, TransactionEntryState>(
        listenWhen: (previous, current) => previous.status != current.status,
        listener: (context, state) {
          if (state.status == TransactionEntryStatus.saved) {
            Navigator.of(context).pop();
          } else if (state.status == TransactionEntryStatus.failure &&
              state.errorMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.errorMessage!)),
            );
          }
        },
        child: Scaffold(
          appBar: AppBar(
            title: Text(isEditing ? 'Edit entry' : 'Add entry'),
            actions: [
              if (widget.existing?.rawCaptureId != null)
                IconButton(
                  icon: AppIcon(AppIcons.eye),
                  tooltip: 'Original message',
                  onPressed: () => RawSourceSheet.show(
                    context,
                    rawCaptureId: widget.existing!.rawCaptureId!,
                  ),
                ),
              if (isEditing)
                IconButton(
                  icon: AppIcon(AppIcons.delete),
                  tooltip: 'Delete',
                  onPressed: () => _confirmDelete(context),
                ),
            ],
          ),
          body: BlocBuilder<TransactionEntryCubit, TransactionEntryState>(
            builder: (context, state) {
              return ListView(
                padding: const EdgeInsets.fromLTRB(
                  Space.gutter,
                  Space.x2,
                  Space.gutter,
                  Space.x3,
                ),
                children: [
                  _DirectionToggle(direction: state.direction),
                  const SizedBox(height: Space.x2),
                  AmountField(
                    controller: _amountController,
                    autofocus: !isEditing,
                    errorText: state.status == TransactionEntryStatus.invalid
                        ? state.errorMessage
                        : null,
                    onChanged: cubit.amountChanged,
                  ),
                  const SizedBox(height: Space.x3),
                  _CategoryPicker(
                    state: state,
                    onAddCategory: () => _addCategory(context),
                  ),
                  const SizedBox(height: Space.x3),
                  AppTextField(
                    controller: _merchantController,
                    label: state.direction == TxDirection.credit
                        ? 'Received from'
                        : 'Merchant or person',
                    textCapitalization: TextCapitalization.words,
                    onChanged: cubit.merchantChanged,
                  ),
                  const SizedBox(height: Space.x2),
                  _DateRow(
                    state: state,
                    onPick: () => _pickDate(context, state.transactedAt),
                  ),
                  const SizedBox(height: Space.x2),
                  _MoreDetails(
                    state: state,
                    descriptionController: _descriptionController,
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
                        : Text(isEditing ? 'Save changes' : 'Save'),
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

/// Spent / Received, carried by both a word and a colour — the arrows
/// this replaced pointed the wrong way for a ledger (money out was up)
/// and said nothing on their own.
class _DirectionToggle extends StatelessWidget {
  const _DirectionToggle({required this.direction});

  final TxDirection direction;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<TransactionEntryCubit>();
    final money = Theme.of(context).extension<MoneyColors>()!;
    final colors = Theme.of(context).colorScheme;

    Widget option(TxDirection value, String label, Color tint) {
      final selected = value == direction;
      return Expanded(
        child: Material(
          color: selected ? tint.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: Radii.chipRadius,
          child: InkWell(
            onTap: () => cubit.directionChanged(value),
            borderRadius: Radii.chipRadius,
            child: Container(
              height: Space.x6,
              alignment: Alignment.center,
              child: Text(
                label,
                style: AppTypography.rowTitle(
                  color: selected ? tint : colors.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: Radii.chipRadius,
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Row(
        children: [
          option(TxDirection.debit, 'Spent', money.outflow),
          option(TxDirection.credit, 'Received', money.inflow),
        ],
      ),
    );
  }
}

/// Categories as a wrapped chip row rather than a flat dropdown, which
/// also flattened away the subcategory hierarchy the model supports.
/// Only categories matching the chosen direction are offered.
class _CategoryPicker extends StatelessWidget {
  const _CategoryPicker({required this.state, required this.onAddCategory});

  final TransactionEntryState state;
  final VoidCallback onAddCategory;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<TransactionEntryCubit>();
    final colors = Theme.of(context).colorScheme;
    final options = state.categoriesForDirection;
    final topLevel = options.where((c) => c.parentId == null).toList();
    final selected = options.where((c) => c.id == state.categoryId).firstOrNull;

    // A subcategory picked from the full list would otherwise vanish
    // from a row that only shows top-level ones.
    final shown = <Category>[
      ...topLevel,
      if (selected != null && selected.parentId != null) selected,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'CATEGORY',
          style: AppTypography.chipOverline(color: colors.onSurfaceVariant),
        ),
        const SizedBox(height: Space.x1),
        Wrap(
          spacing: Space.x1,
          runSpacing: Space.x1,
          children: [
            for (final category in shown)
              ChoiceChip(
                label: Text(category.name),
                avatar: CategoryAvatar(
                  iconKey: category.icon,
                  categoryId: category.id,
                  colorName: category.color,
                  size: 20,
                ),
                selected: category.id == state.categoryId,
                onSelected: (isSelected) =>
                    cubit.categoryChanged(isSelected ? category.id : null),
              ),
            ActionChip(
              avatar: AppIcon(AppIcons.add, size: 16),
              label: const Text('New'),
              onPressed: onAddCategory,
            ),
          ],
        ),
      ],
    );
  }
}

/// Today / Yesterday / a picked date. The date defaults to now, so
/// most entries never open a picker at all.
class _DateRow extends StatelessWidget {
  const _DateRow({required this.state, required this.onPick});

  final TransactionEntryState state;
  final VoidCallback onPick;

  static final _dateFormat = DateFormat('d MMM yyyy, HH:mm');

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<TransactionEntryCubit>();
    final colors = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(days: 1));
    final isToday = state.isOnDay(now);
    final isYesterday = state.isOnDay(yesterday);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'WHEN',
          style: AppTypography.chipOverline(color: colors.onSurfaceVariant),
        ),
        const SizedBox(height: Space.x1),
        Wrap(
          spacing: Space.x1,
          runSpacing: Space.x1,
          children: [
            ChoiceChip(
              label: const Text('Today'),
              selected: isToday,
              onSelected: (_) => cubit.dayShortcutSelected(now),
            ),
            ChoiceChip(
              label: const Text('Yesterday'),
              selected: isYesterday,
              onSelected: (_) => cubit.dayShortcutSelected(yesterday),
            ),
            ActionChip(
              avatar: AppIcon(AppIcons.calendar, size: 16),
              label: Text(
                isToday || isYesterday
                    ? 'Pick'
                    : _dateFormat.format(state.transactedAt),
              ),
              onPressed: onPick,
            ),
          ],
        ),
      ],
    );
  }
}

/// Everything that is usually left at its default. Collapsed so the
/// first screen stays the four fields that actually matter.
class _MoreDetails extends StatelessWidget {
  const _MoreDetails({
    required this.state,
    required this.descriptionController,
  });

  final TransactionEntryState state;
  final TextEditingController descriptionController;

  Future<void> _addPayee(BuildContext context) async {
    final cubit = context.read<TransactionEntryCubit>();
    final name = await _promptForName(context, 'Add payee');
    if (name == null || name.trim().isEmpty) return;
    await cubit.payeeAdded(name);
  }

  Future<void> _addLabel(BuildContext context) async {
    final cubit = context.read<TransactionEntryCubit>();
    final name = await _promptForName(context, 'Add label');
    if (name == null || name.trim().isEmpty) return;
    await cubit.labelAdded(name);
  }

  /// A sheet rather than the `AlertDialog` this used to be — a dialog
  /// interrupts a form the user is halfway through, and the keyboard
  /// covers it on a short screen.
  Future<String?> _promptForName(BuildContext context, String title) {
    final controller = TextEditingController();
    return AppSheet.show<String>(
      context,
      builder: (sheetContext) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: AppTypography.sectionHeader()),
          const SizedBox(height: Space.x2),
          AppTextField(
            controller: controller,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            onSubmitted: (value) => Navigator.of(sheetContext).pop(value),
          ),
          const SizedBox(height: Space.x2),
          FilledButton(
            onPressed: () => Navigator.of(sheetContext).pop(controller.text),
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<TransactionEntryCubit>();
    final colors = Theme.of(context).colorScheme;

    return Theme(
      // The default expansion tile draws its own dividers, which fight
      // the card border already around it.
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        title: Text(
          'More details',
          style: AppTypography.rowTitle(color: colors.onSurface),
        ),
        subtitle: Text(
          'Account, payee, note, labels, receipt',
          style: AppTypography.metadata(color: colors.onSurfaceVariant),
        ),
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: Space.x1),
        children: [
          if (state.accounts.isNotEmpty) ...[
            DropdownButtonFormField<String>(
              initialValue: state.accounts.any((a) => a.id == state.accountId)
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
            const SizedBox(height: Space.x2),
          ],
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String?>(
                  initialValue: state.payees.any((p) => p.id == state.payeeId)
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
                icon: AppIcon(AppIcons.add),
                tooltip: 'Add payee',
                onPressed: () => _addPayee(context),
              ),
            ],
          ),
          const SizedBox(height: Space.x2),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              'Already paid',
              style: AppTypography.rowTitle(color: colors.onSurface),
            ),
            subtitle: state.isPaid
                ? null
                : Text(
                    "Recorded as planned — won't count toward totals "
                    'until paid',
                    style: AppTypography.metadata(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
            value: state.isPaid,
            onChanged: cubit.paidChanged,
          ),
          const SizedBox(height: Space.x1),
          AppTextField(
            controller: descriptionController,
            label: 'Note',
            onChanged: cubit.descriptionChanged,
          ),
          const SizedBox(height: Space.x2),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'LABELS',
              style: AppTypography.chipOverline(
                color: colors.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: Space.x1),
          Wrap(
            spacing: Space.x1,
            runSpacing: Space.x1,
            children: [
              for (final label in state.labels)
                FilterChip(
                  label: Text(label.name),
                  selected: state.labelIds.contains(label.id),
                  onSelected: (_) => cubit.labelToggled(label.id),
                ),
              ActionChip(
                avatar: AppIcon(AppIcons.add, size: 16),
                label: const Text('Add label'),
                onPressed: () => _addLabel(context),
              ),
            ],
          ),
          const SizedBox(height: Space.x2),
          _ReceiptField(receiptPath: state.receiptPath),
        ],
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
    final source = await AppSheet.show<ImageSource>(
      context,
      isScrollControlled: false,
      builder: (sheetContext) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppListRow(
            leading: AppIcon(AppIcons.scanReceipt),
            title: const Text('Take photo'),
            onTap: () => Navigator.of(sheetContext).pop(ImageSource.camera),
          ),
          AppListRow(
            leading: AppIcon(AppIcons.exportData),
            title: const Text('Choose from gallery'),
            onTap: () => Navigator.of(sheetContext).pop(ImageSource.gallery),
          ),
        ],
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
    final colors = Theme.of(context).colorScheme;

    if (receiptPath == null) {
      return OutlinedButton.icon(
        onPressed: () => _pick(context),
        icon: AppIcon(AppIcons.scanReceipt, size: 18),
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
              color: colors.surfaceContainerHigh,
              child: AppIcon(AppIcons.unknown, size: 20),
            ),
          ),
        ),
        const SizedBox(width: Space.x1),
        Expanded(
          child: Text(
            'Receipt attached',
            style: AppTypography.body(color: colors.onSurface),
          ),
        ),
        TextButton(
          onPressed: () => _pick(context),
          child: const Text('Replace'),
        ),
        IconButton(
          icon: AppIcon(AppIcons.delete),
          tooltip: 'Remove receipt',
          onPressed: () =>
              context.read<TransactionEntryCubit>().removeReceipt(),
        ),
      ],
    );
  }
}
