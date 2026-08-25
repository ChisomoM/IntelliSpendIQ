/// One turn of a raw tool-use conversation with an LLM.
///
/// Deliberately narrow: this makes exactly one API call and hands back
/// what came back, with no notion of transactions, budgets, or
/// repositories. `FinanceChatService` owns the tool-use loop and the
/// domain meaning of each tool; this interface only ever sees a message
/// history and a tool list, matching the plan's rule that feature code
/// never imports the Anthropic SDK — only this abstraction.
abstract interface class ChatProvider {
  Future<bool> get isConfigured;

  /// Sends [messages] (Anthropic wire format — each a `{role, content}`
  /// map) with the given [tools], and returns Claude's raw content
  /// blocks and stop reason.
  ///
  /// When [onTextDelta] is provided, implementations that support
  /// streaming should invoke it with each incremental text chunk so the
  /// UI can render a reply before the full turn finishes.
  Future<ChatCompletion> complete({
    required List<Map<String, dynamic>> messages,
    required List<Map<String, dynamic>> tools,
    void Function(String delta)? onTextDelta,
  });
}

class ChatCompletion {
  const ChatCompletion({required this.content, required this.stopReason});

  /// Raw content blocks — `text` and/or one or more `tool_use` blocks.
  final List<Map<String, dynamic>> content;

  /// `end_turn`, `tool_use`, `max_tokens`, or `refusal`.
  final String stopReason;
}

class ChatException implements Exception {
  ChatException(this.message);

  final String message;

  @override
  String toString() => message;
}
