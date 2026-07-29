import 'dart:async';

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

  void draftChanged(String value) => emit(state.copyWith(draft: value));

  Future<void> send() async {
    final text = state.draft.trim();
    if (text.isEmpty || state.status == ChatTurnStatus.working) return;

    emit(
      state.copyWith(
        status: ChatTurnStatus.working,
        draft: '',
        messages: [
          ...state.messages,
          ChatMessage(role: ChatRole.user, text: text),
        ],
      ),
    );

    await _runTurn(() => _service.send(history: _wireHistory, userText: text));
  }

  Future<void> confirmAction(ProposedAction action) async {
    if (state.status == ChatTurnStatus.working) return;
    emit(state.copyWith(status: ChatTurnStatus.working));
    await _runTurn(
      () => _service.confirm(history: _wireHistory, action: action),
    );
  }

  Future<void> dismissAction(ProposedAction action) async {
    if (state.status == ChatTurnStatus.working) return;
    emit(state.copyWith(status: ChatTurnStatus.working));
    await _runTurn(
      () => _service.dismiss(history: _wireHistory, action: action),
    );
  }

  Future<void> _runTurn(Future<ChatTurnResult> Function() run) async {
    try {
      final result = await run();
      _wireHistory = result.wireHistory;
      emit(
        state.copyWith(
          status: ChatTurnStatus.idle,
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
