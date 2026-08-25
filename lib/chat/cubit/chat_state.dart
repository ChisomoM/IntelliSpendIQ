part of 'chat_cubit.dart';

enum ChatTurnStatus { idle, working }

class ChatState extends Equatable {
  const ChatState({
    this.messages = const [],
    this.pendingActions = const [],
    this.status = ChatTurnStatus.idle,
    this.draft = '',
    this.streamingText,
    this.errorMessage,
  });

  final List<ChatMessage> messages;

  /// Proposed writes awaiting a confirm/dismiss tap. The conversation
  /// does not continue until these are resolved.
  final List<ProposedAction> pendingActions;
  final ChatTurnStatus status;
  final String draft;

  /// Incremental assistant text while a turn is in flight. Null when
  /// idle; empty string means "thinking" with no tokens yet.
  final String? streamingText;
  final String? errorMessage;

  bool get isEmpty => messages.isEmpty && streamingText == null;

  ChatState copyWith({
    List<ChatMessage>? messages,
    List<ProposedAction>? pendingActions,
    ChatTurnStatus? status,
    String? draft,
    String? streamingText,
    bool clearStreamingText = false,
    String? errorMessage,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      pendingActions: pendingActions ?? this.pendingActions,
      status: status ?? this.status,
      draft: draft ?? this.draft,
      streamingText:
          clearStreamingText ? null : (streamingText ?? this.streamingText),
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [
    messages,
    pendingActions,
    status,
    draft,
    streamingText,
    errorMessage,
  ];
}
