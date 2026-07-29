part of 'chat_cubit.dart';

enum ChatTurnStatus { idle, working }

class ChatState extends Equatable {
  const ChatState({
    this.messages = const [],
    this.pendingActions = const [],
    this.status = ChatTurnStatus.idle,
    this.draft = '',
    this.errorMessage,
  });

  final List<ChatMessage> messages;

  /// Proposed writes awaiting a confirm/dismiss tap. The conversation
  /// does not continue until these are resolved.
  final List<ProposedAction> pendingActions;
  final ChatTurnStatus status;
  final String draft;
  final String? errorMessage;

  bool get isEmpty => messages.isEmpty;

  ChatState copyWith({
    List<ChatMessage>? messages,
    List<ProposedAction>? pendingActions,
    ChatTurnStatus? status,
    String? draft,
    String? errorMessage,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      pendingActions: pendingActions ?? this.pendingActions,
      status: status ?? this.status,
      draft: draft ?? this.draft,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [
    messages,
    pendingActions,
    status,
    draft,
    errorMessage,
  ];
}
