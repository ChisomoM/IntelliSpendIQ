import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intellispendiq/domain/models/custom_sender.dart';
import 'package:intellispendiq/domain/parsers/parser_registry.dart';
import 'package:intellispendiq/senders/cubit/cubit.dart';

class CustomSenderTile extends StatelessWidget {
  const CustomSenderTile({required this.sender, super.key});

  final CustomSender sender;

  @override
  Widget build(BuildContext context) {
    final providers = context.read<ParserRegistry>().providers;
    final providerName =
        providers
            .where((p) => p.key == sender.providerKey)
            .map((p) => p.displayName)
            .firstOrNull ??
        sender.providerKey;

    return ListTile(
      leading: const CircleAvatar(child: Icon(Icons.sms_outlined)),
      title: Text(sender.senderId),
      subtitle: Text('Routes to $providerName'),
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline),
        tooltip: 'Remove',
        onPressed: () => context.read<CustomSendersCubit>().delete(sender),
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
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
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
    final providers = context.read<ParserRegistry>().providers;
    _providerKey ??= providers.firstOrNull?.key;

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Add a message sender',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            "If a bank or wallet's SMS alerts aren't being captured, add "
            'the sender ID shown on the message here.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
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
          const SizedBox(height: 16),
          TextField(
            controller: _senderController,
            decoration: InputDecoration(
              labelText: 'Sender ID',
              hintText: 'e.g. AirtelMoney or a shortcode',
              errorText: _error,
            ),
            autofocus: true,
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _providerKey == null ? null : () => _save(_providerKey!),
            child: const Text('Add sender'),
          ),
        ],
      ),
    );
  }
}

class NoCustomSendersYet extends StatelessWidget {
  const NoCustomSendersYet({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.sms_outlined, size: 48),
            const SizedBox(height: 16),
            const Text(
              'No extra senders added',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Airtel Money and Standard Chartered are recognized '
              'automatically. Add a sender ID here if another bank or '
              "wallet's alerts aren't being captured.",
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => CustomSenderEditorSheet.show(context),
              child: const Text('Add a sender'),
            ),
          ],
        ),
      ),
    );
  }
}
