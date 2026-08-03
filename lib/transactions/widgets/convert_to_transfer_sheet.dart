import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intellispendiq/design/design.dart';
import 'package:intellispendiq/domain/models/enums.dart';
import 'package:intellispendiq/transactions/cubit/cubit.dart';

/// Picks the other account and turns the entry being edited into a
/// transfer. Amount and date stay as shown on the edit form; from/to
/// follow the persisted direction of the original transaction.
class ConvertToTransferSheet extends StatefulWidget {
  const ConvertToTransferSheet({super.key});

  static Future<void> show(BuildContext context) {
    final cubit = context.read<TransactionEntryCubit>();
    return AppSheet.show<void>(
      context,
      builder: (_) => BlocProvider.value(
        value: cubit,
        child: const ConvertToTransferSheet(),
      ),
    );
  }

  @override
  State<ConvertToTransferSheet> createState() => _ConvertToTransferSheetState();
}

class _ConvertToTransferSheetState extends State<ConvertToTransferSheet> {
  late final TextEditingController _noteController;
  late final TextEditingController _feeController;
  String? _otherAccountId;
  String? _error;

  @override
  void initState() {
    super.initState();
    final cubit = context.read<TransactionEntryCubit>();
    _noteController = TextEditingController(
      text: cubit.prefilledTransferNote ?? '',
    );
    _feeController = TextEditingController();
  }

  @override
  void dispose() {
    _noteController.dispose();
    _feeController.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    final otherAccountId = _otherAccountId;
    if (otherAccountId == null) {
      setState(() => _error = 'Pick the other account');
      return;
    }

    final cubit = context.read<TransactionEntryCubit>();
    final navigator = Navigator.of(context);
    await cubit.convertToTransfer(
      otherAccountId: otherAccountId,
      note: _noteController.text,
      fee: _feeController.text,
    );
    if (!mounted) return;
    final status = cubit.state.status;
    if (status == TransactionEntryStatus.invalid ||
        status == TransactionEntryStatus.failure) {
      setState(() => _error = cubit.state.errorMessage);
      return;
    }
    // Edit entry listens for `saved` and pops itself; close the sheet.
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.watch<TransactionEntryCubit>();
    final state = cubit.state;
    final colors = Theme.of(context).colorScheme;
    final sourceAccountId = cubit.transferSourceAccountId;
    final sourceName = state.accounts
        .where((a) => a.id == sourceAccountId)
        .map((a) => a.name)
        .firstOrNull;
    final counterparts = state.accounts
        .where((a) => a.id != sourceAccountId)
        .toList();
    final isDebit = cubit.transferSourceDirection == TxDirection.debit;
    final otherName = counterparts
        .where((a) => a.id == _otherAccountId)
        .map((a) => a.name)
        .firstOrNull;

    if (counterparts.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(Space.x3),
        child: Text(
          'Add a second account before converting this entry into a transfer.',
          style: AppTypography.body(color: colors.onSurfaceVariant),
        ),
      );
    }

    final summary = sourceName == null
        ? 'This entry becomes a transfer and will not count as spend or income.'
        : isDebit
        ? otherName == null
              ? 'Money left $sourceName for another account. This entry '
                    'becomes a transfer and will not count as spend or income.'
              : 'Money left $sourceName for $otherName. This entry '
                    'becomes a transfer and will not count as spend or income.'
        : otherName == null
        ? 'Money arrived in $sourceName from another account. This entry '
              'becomes a transfer and will not count as spend or income.'
        : 'Money arrived in $sourceName from $otherName. This entry '
              'becomes a transfer and will not count as spend or income.';

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('This was a transfer', style: AppTypography.sectionHeader()),
        const SizedBox(height: Space.x1),
        Text(
          summary,
          style: AppTypography.metadata(color: colors.onSurfaceVariant),
        ),
        const SizedBox(height: Space.x2),
        DropdownButtonFormField<String>(
          initialValue: _otherAccountId,
          decoration: InputDecoration(
            labelText: isDebit ? 'To account' : 'From account',
            errorText: _error,
          ),
          items: [
            for (final account in counterparts)
              DropdownMenuItem(
                value: account.id,
                child: Text(account.name),
              ),
          ],
          onChanged: (value) => setState(() {
            _otherAccountId = value;
            _error = null;
          }),
        ),
        const SizedBox(height: Space.x2),
        AmountField(
          controller: _feeController,
          label: 'Fee (optional)',
        ),
        const SizedBox(height: Space.x2),
        AppTextField(
          controller: _noteController,
          label: 'Note (optional)',
        ),
        const SizedBox(height: Space.x2),
        AppButton.primary(
          label: 'Convert to transfer',
          onPressed: state.isSaving ? null : _confirm,
        ),
      ],
    );
  }
}
