import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intellispendiq/design/design.dart';
import 'package:intellispendiq/domain/models/custom_sender.dart';
import 'package:intellispendiq/domain/parsers/parser_registry.dart';
import 'package:intellispendiq/senders/cubit/cubit.dart';

class CustomSenderTile extends StatelessWidget {
  const CustomSenderTile({required this.sender, super.key});

  final CustomSender sender;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final providers = context.read<ParserRegistry>().providers;
    final providerName =
        providers
            .where((p) => p.key == sender.providerKey)
            .map((p) => p.displayName)
            .firstOrNull ??
        sender.providerKey;

    return Padding(
      padding: const EdgeInsets.only(bottom: Space.cardGap),
      child: AppCard(
        padding: EdgeInsets.zero,
        child: AppListRow(
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.10),
              borderRadius: Radii.inputRadius,
            ),
            alignment: Alignment.center,
            child: AppIcon(AppIcons.senders, size: 18, color: colors.primary),
          ),
          title: Text(sender.senderId),
          subtitle: Text('Routes to $providerName'),
          trailing: IconButton(
            icon: AppIcon(AppIcons.delete, size: 20, color: colors.onSurfaceVariant),
            tooltip: 'Remove',
            onPressed: () => context.read<CustomSendersCubit>().delete(sender),
          ),
        ),
      ),
    );
  }
}

/// Adds a sender ID the built-in parsers don't already recognize,
/// routing it to an existing provider.
class CustomSenderEditorSheet extends StatefulWidget {
  const CustomSenderEditorSheet({super.key});

  static Future<void> show(BuildContext context) {
    final cubit = context.read<CustomSendersCubit>();
    final registry = context.read<ParserRegistry>();
    return AppSheet.show<void>(
      context,
      builder: (_) => MultiBlocProvider(
        providers: [
          BlocProvider.value(value: cubit),
          RepositoryProvider.value(value: registry),
        ],
        child: const CustomSenderEditorSheet(),
      ),
    );
  }

  @override
  State<CustomSenderEditorSheet> createState() =>
      _CustomSenderEditorSheetState();
}

class _CustomSenderEditorSheetState extends State<CustomSenderEditorSheet> {
  final _senderController = TextEditingController();
  String? _providerKey;
  String? _error;

  @override
  void dispose() {
    _senderController.dispose();
    super.dispose();
  }

  Future<void> _save(String providerKey) async {
    final navigator = Navigator.of(context);
    await context.read<CustomSendersCubit>().add(
      providerKey: providerKey,
      senderId: _senderController.text,
    );
    if (!mounted) return;
    final state = context.read<CustomSendersCubit>().state;
    if (state.status == CustomSendersStatus.invalid) {
      setState(() => _error = state.errorMessage);
      return;
    }
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final providers = context.read<ParserRegistry>().providers;
    _providerKey ??= providers.firstOrNull?.key;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Add a message sender', style: AppTypography.sectionHeader()),
        const SizedBox(height: Space.x1),
        Text(
          "If a bank or wallet's SMS alerts aren't being captured, add "
          'the sender ID shown on the message here.',
          style: AppTypography.metadata(color: colors.onSurfaceVariant),
        ),
        const SizedBox(height: Space.x2),
        DropdownButtonFormField<String>(
          initialValue: _providerKey,
          decoration: const InputDecoration(labelText: 'Routes to'),
          items: [
            for (final provider in providers)
              DropdownMenuItem(
                value: provider.key,
                child: Text(provider.displayName),
              ),
          ],
          onChanged: (value) => setState(() => _providerKey = value),
        ),
        const SizedBox(height: Space.x2),
        AppTextField(
          controller: _senderController,
          label: 'Sender ID',
          hint: 'e.g. AirtelMoney or a shortcode',
          errorText: _error,
          autofocus: true,
        ),
        const SizedBox(height: Space.x3),
        AppButton.primary(
          label: 'Add sender',
          onPressed: _providerKey == null ? null : () => _save(_providerKey!),
        ),
      ],
    );
  }
}

class NoCustomSendersYet extends StatelessWidget {
  const NoCustomSendersYet({super.key});

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: AppIcons.senders,
      title: 'No extra senders added',
      message: 'Airtel Money and Standard Chartered are recognized '
          'automatically. Add a sender ID here if another bank or '
          "wallet's alerts aren't being captured.",
      actionLabel: 'Add a sender',
      onAction: () => CustomSenderEditorSheet.show(context),
    );
  }
}
