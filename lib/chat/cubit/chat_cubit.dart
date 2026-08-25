import 'dart:async';
import 'dart:convert';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:intellispendiq/domain/models/chat_message.dart';
import 'package:intellispendiq/domain/models/proposed_action.dart';
import 'package:intellispendiq/domain/services/finance_chat_service.dart';

part 'chat_state.dart';

/// Drives the finance chat: a transcript plus, when the assistant
/// proposes writing something, a confirmation card that pauses the
/// conversation until the user accepts or declines it.
///
/// The Anthropic-format message history the service needs to resume a
/// paused turn lives only in `_wireHistory` here — never in `ChatState`,
/// because the UI has no business rendering tool_use/tool_result
/// blocks. It also isn't persisted: this is an in-memory session that
/// starts fresh each time the chat is opened.
class ChatCubit extends Cubit<ChatState> {
  ChatCubit(this._service) : super(const ChatState());

  final FinanceChatService _service;
  List<Map<String, dynamic>> _wireHistory = [];
  List<Map<String, dynamic>> _deferredToolResults = [];

  void draftChanged(String value) => emit(state.copyWith(draft: value));

  Future<void> send() async {
    final text = state.draft.trim();
    if (text.isEmpty || state.status == ChatTurnStatus.working) return;

    emit(
      state.copyWith(
        status: ChatTurnStatus.working,
        draft: '',
        streamingText: '',
        messages: [
          ...state.messages,
          ChatMessage(role: ChatRole.user, text: text),
        ],
      ),
    );

    await _runTurn(
      () => _service.send(
        history: _wireHistory,
        userText: text,
        onPartialText: _onPartialText,
      ),
    );
  }

  Future<void> confirmAction(ProposedAction action) async {
    if (state.status == ChatTurnStatus.working) return;
    emit(
      state.copyWith(
        status: ChatTurnStatus.working,
        streamingText: '',
      ),
    );
    final siblings = state.pendingActions
        .where((item) => item.toolUseId != action.toolUseId)
        .toList(growable: false);
    final deferred = [
      ..._deferredToolResults,
      for (final sibling in siblings)
        {
          'type': 'tool_result',
          'tool_use_id': sibling.toolUseId,
          'content': jsonEncode({'confirmed': false}),
        },
    ];
    _deferredToolResults = [];
    await _runTurn(
      () => _service.confirm(
        history: _wireHistory,
        action: action,
        deferredToolResults: deferred,
        onPartialText: _onPartialText,
      ),
    );
  }

  Future<void> dismissAction(ProposedAction action) async {
    if (state.status == ChatTurnStatus.working) return;
    emit(
      state.copyWith(
        status: ChatTurnStatus.working,
        streamingText: '',
      ),
    );
    final siblings = state.pendingActions
        .where((item) => item.toolUseId != action.toolUseId)
        .toList(growable: false);
    final deferred = [
      ..._deferredToolResults,
      for (final sibling in siblings)
        {
          'type': 'tool_result',
          'tool_use_id': sibling.toolUseId,
          'content': jsonEncode({'confirmed': false}),
        },
    ];
    _deferredToolResults = [];
    await _runTurn(
      () => _service.dismiss(
        history: _wireHistory,
        action: action,
        deferredToolResults: deferred,
        onPartialText: _onPartialText,
      ),
    );
  }

  void _onPartialText(String partial) {
    if (isClosed) return;
    emit(state.copyWith(streamingText: partial));
  }

  Future<void> _runTurn(Future<ChatTurnResult> Function() run) async {
    try {
      final result = await run();
      _wireHistory = result.wireHistory;
      _deferredToolResults = result.deferredToolResults;
      emit(
        state.copyWith(
          status: ChatTurnStatus.idle,
          clearStreamingText: true,
          messages: [
            ...state.messages,
            if (result.assistantText.isNotEmpty)
              ChatMessage(role: ChatRole.assistant, text: result.assistantText),
          ],
          pendingActions: result.pending,
        ),
      );
    } on Object catch (error) {
      emit(
        state.copyWith(
          status: ChatTurnStatus.idle,
          clearStreamingText: true,
          errorMessage: 'Could not reach the assistant: $error',
        ),
      );
    }
  }

  void sendUnawaited() => unawaited(send());

  void confirmActionUnawaited(ProposedAction action) =>
      unawaited(confirmAction(action));

  void dismissActionUnawaited(ProposedAction action) =>
      unawaited(dismissAction(action));
}
