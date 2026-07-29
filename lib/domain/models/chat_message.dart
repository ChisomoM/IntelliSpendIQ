import 'package:equatable/equatable.dart';

enum ChatRole { user, assistant }

/// One line of the visible chat transcript.
///
/// Deliberately not the same shape as the wire-format messages
/// `FinanceChatService` exchanges with Claude — those carry tool_use /
/// tool_result blocks the user never sees; this is display-only.
class ChatMessage extends Equatable {
  const ChatMessage({required this.role, required this.text});

  final ChatRole role;
  final String text;

  @override
  List<Object?> get props => [role, text];
}
