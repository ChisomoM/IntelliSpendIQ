import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intellispendiq/core/money.dart';
import 'package:intellispendiq/domain/voice/voice_pipeline.dart';
import 'package:intellispendiq/transactions/transactions.dart';
import 'package:intellispendiq/voice/cubit/cubit.dart';

/// Quick-add by voice. On-device transcription is not wired yet
/// (Phase 1d evaluates the whisper.cpp binding), so this sheet takes the
/// utterance as text and runs the same extraction → confidence routing
/// the recorded path will use.
class VoiceEntrySheet extends StatelessWidget {
  const VoiceEntrySheet({super.key});

  static Future<void> show(BuildContext context) {
    final pipeline = context.read<VoicePipeline>();
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => BlocProvider(
        create: (_) => VoiceEntryCubit(pipeline),
        child: const VoiceEntrySheet(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<VoiceEntryCubit>();
    final theme = Theme.of(context);

    return BlocConsumer<VoiceEntryCubit, VoiceEntryState>(
      listenWhen: (previous, current) => previous.status != current.status,
      listener: (context, state) {
        switch (state.status) {
          case VoiceEntryStatus.autoSaved:
            Navigator.of(context).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Saved ${Money.format(state.transaction!.amountMinor)}',
                ),
              ),
            );
          case VoiceEntryStatus.needsReview:
            final navigator = Navigator.of(context)..pop();
            unawaited(
              navigator.push<void>(
                TransactionEntryPage.route(existing: state.transaction),
              ),
            );
          case VoiceEntryStatus.editing:
          case VoiceEntryStatus.working:
          case VoiceEntryStatus.storedForReview:
            break;
        }
      },
      builder: (context, state) {
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
              Row(
                children: [
                  const Icon(Icons.mic),
                  const SizedBox(width: 8),
                  Text('Quick add', style: theme.textTheme.titleLarge),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Describe the spend the way you would say it — '
                '"spent 50 kwacha on a taxi to town".',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                autofocus: true,
                minLines: 2,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: 'What did you spend?',
                ),
                onChanged: cubit.transcriptChanged,
                onSubmitted: (_) => cubit.submit(),
              ),
              if (state.status == VoiceEntryStatus.storedForReview) ...[
                const SizedBox(height: 12),
                Text(
                  '${state.errorMessage ?? 'Could not read that'} — the note '
                  'was saved to your Review inbox.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ],
              const SizedBox(height: 20),
              FilledButton(
                onPressed: state.isWorking ? null : cubit.submit,
                child: state.isWorking
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Add'),
              ),
            ],
          ),
        );
      },
    );
  }
}
