import 'package:flutter/material.dart';
import 'package:intellispendiq/app/app.dart';
import 'package:intellispendiq/core/money.dart';
import 'package:intellispendiq/domain/voice/voice_pipeline.dart';
import 'package:intellispendiq/features/transactions/transaction_entry_page.dart';

/// Quick-add by voice. On-device transcription is not wired yet
/// (Phase 1d evaluates the whisper.cpp binding), so this sheet takes the
/// utterance as text and runs the same extraction → confidence routing
/// the recorded path will use.
class VoiceEntrySheet extends StatefulWidget {
  const VoiceEntrySheet({super.key});

  @override
  State<VoiceEntrySheet> createState() => _VoiceEntrySheetState();
}

class _VoiceEntrySheetState extends State<VoiceEntrySheet> {
  final _controller = TextEditingController();
  bool _working = false;
  String? _message;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final transcript = _controller.text.trim();
    if (transcript.isEmpty) return;

    setState(() {
      _working = true;
      _message = null;
    });

    final services = AppScope.of(context);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    final result = await services.voicePipeline.processTranscript(transcript);
    if (!mounted) return;

    switch (result.outcome) {
      case VoiceOutcome.autoSaved:
        navigator.pop();
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              'Saved ${Money.format(result.transaction!.amountMinor)}',
            ),
          ),
        );
      case VoiceOutcome.needsReview:
        navigator.pop();
        await navigator.push<void>(
          MaterialPageRoute(
            builder: (_) => TransactionEntryPage(existing: result.transaction),
          ),
        );
      case VoiceOutcome.storedForReview:
        setState(() {
          _working = false;
          _message =
              '${result.error ?? 'Could not read that'} — the note was saved '
              'to your Review inbox.';
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
            controller: _controller,
            autofocus: true,
            minLines: 2,
            maxLines: 4,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(hintText: 'What did you spend?'),
            onSubmitted: (_) => _submit(),
          ),
          if (_message != null) ...[
            const SizedBox(height: 12),
            Text(
              _message!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _working ? null : _submit,
            child: _working
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
  }
}
