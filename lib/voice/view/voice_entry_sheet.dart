import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intellispendiq/core/money.dart';
import 'package:intellispendiq/domain/voice/voice_pipeline.dart';
import 'package:intellispendiq/transactions/transactions.dart';
import 'package:intellispendiq/voice/cubit/cubit.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Quick-add by voice. The device's own speech recognizer transcribes
/// speech live into the same text field a typed entry would use, so
/// everything downstream — extraction, confidence routing, review —
/// is exactly the same pipeline either way. Typing always still
/// works, including on a device with no speech recognizer at all.
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
    return BlocConsumer<VoiceEntryCubit, VoiceEntryState>(
      listenWhen: (previous, current) => previous.status != current.status,
      listener: (context, state) {
        switch (state.status) {
          case VoiceEntryStatus.autoSaved:
            Navigator.of(context).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Saved ${Money.display(state.transaction!.amountMinor)}',
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
      builder: (context, state) => _VoiceEntryBody(state: state),
    );
  }
}

class _VoiceEntryBody extends StatefulWidget {
  const _VoiceEntryBody({required this.state});

  final VoiceEntryState state;

  @override
  State<_VoiceEntryBody> createState() => _VoiceEntryBodyState();
}

class _VoiceEntryBodyState extends State<_VoiceEntryBody> {
  final _speech = SpeechToText();
  late final TextEditingController _controller;
  bool _speechAvailable = false;
  bool _listening = false;
  String? _speechError;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.state.transcript);
    unawaited(_initSpeech());
  }

  Future<void> _initSpeech() async {
    final available = await _speech.initialize(
      onError: (error) {
        if (!mounted) return;
        setState(() {
          _listening = false;
          if (error.permanent) {
            // The recognizer itself is unusable — fall back to typing
            // only rather than leaving a dead mic button on screen.
            _speechAvailable = false;
          } else {
            _speechError = "Didn't catch that — try again or type it.";
          }
        });
      },
      onStatus: (status) {
        if (!mounted) return;
        if (status == 'notListening' || status == 'done') {
          setState(() => _listening = false);
        }
      },
    );
    if (!mounted) return;
    setState(() => _speechAvailable = available);
  }

  @override
  void dispose() {
    unawaited(_speech.stop());
    _controller.dispose();
    super.dispose();
  }

  void _toggleListening() {
    if (_listening) {
      unawaited(_speech.stop());
      setState(() => _listening = false);
      return;
    }

    setState(() {
      _listening = true;
      _speechError = null;
    });
    unawaited(
      _speech.listen(
        onResult: _onSpeechResult,
        listenOptions: SpeechListenOptions(
          listenMode: ListenMode.dictation,
          pauseFor: const Duration(seconds: 3),
          listenFor: const Duration(seconds: 30),
        ),
      ),
    );
  }

  void _onSpeechResult(SpeechRecognitionResult result) {
    _controller.text = result.recognizedWords;
    context.read<VoiceEntryCubit>().transcriptChanged(result.recognizedWords);
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<VoiceEntryCubit>();
    final theme = Theme.of(context);
    final state = widget.state;

    if (!_listening && _controller.text != state.transcript) {
      _controller.text = state.transcript;
    }

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
              Expanded(
                child: Text('Quick add', style: theme.textTheme.titleLarge),
              ),
              if (_speechAvailable)
                IconButton.filledTonal(
                  icon: Icon(_listening ? Icons.stop : Icons.mic_none),
                  tooltip: _listening ? 'Stop' : 'Speak',
                  color: _listening ? theme.colorScheme.error : null,
                  onPressed: _toggleListening,
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _speechAvailable
                ? 'Tap the mic and describe the spend the way you would '
                      'say it — "spent 50 kwacha on a taxi to town" — or '
                      'type it below.'
                : 'Describe the spend the way you would say it — '
                      '"spent 50 kwacha on a taxi to town".',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autofocus: !_speechAvailable,
            minLines: 2,
            maxLines: 4,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              hintText: 'What did you spend?',
            ),
            onChanged: cubit.transcriptChanged,
            onSubmitted: (_) => cubit.submit(),
          ),
          if (_listening) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: theme.colorScheme.error,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Listening…',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ],
            ),
          ],
          if (_speechError != null) ...[
            const SizedBox(height: 8),
            Text(
              _speechError!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
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
  }
}
