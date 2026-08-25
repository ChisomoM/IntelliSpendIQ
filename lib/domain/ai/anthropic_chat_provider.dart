import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:intellispendiq/config/resolve_anthropic_api_key.dart';
import 'package:intellispendiq/data/secure/secure_store.dart';
import 'package:intellispendiq/domain/ai/chat_provider.dart';

/// Claude via the Anthropic Messages API, for the finance chat assistant.
///
/// Sibling to `AnthropicClaudeProvider` rather than a shared class: that
/// provider forces a single strict tool call for extraction, while this
/// one carries an open-ended message history and lets Claude choose
/// between replying in text or calling a tool. Bundling both shapes into
/// one class would blur what each call site can rely on.
class AnthropicChatProvider implements ChatProvider {
  AnthropicChatProvider({
    required SecureStore secureStore,
    http.Client? httpClient,
    this.model = 'claude-haiku-4-5',
  }) : _secureStore = secureStore,
       _http = httpClient ?? http.Client();

  static const _endpoint = 'https://api.anthropic.com/v1/messages';
  static const _apiVersion = '2023-06-01';

  final SecureStore _secureStore;
  final http.Client _http;
  final String model;

  @override
  Future<bool> get isConfigured async {
    final key = await resolveAnthropicApiKey(_secureStore);
    return key != null && key.isNotEmpty;
  }

  @override
  Future<ChatCompletion> complete({
    required List<Map<String, dynamic>> messages,
    required List<Map<String, dynamic>> tools,
    void Function(String delta)? onTextDelta,
  }) async {
    final apiKey = await resolveAnthropicApiKey(_secureStore);
    if (apiKey == null || apiKey.isEmpty) {
      throw ChatException('Anthropic API key not configured');
    }

    final body = jsonEncode({
      'model': model,
      'max_tokens': 2048,
      'stream': true,
      'tools': tools,
      // Parallel read tools cut round-trips; the service loop accepts
      // multiple tool_use blocks and pauses cleanly on propose_* actions.
      'tool_choice': {'type': 'auto', 'disable_parallel_tool_use': false},
      'system':
          'You are the finance assistant inside IntelliSpendIQ, a personal '
          'expense tracker for a user in Zambia (currency ZMW; "K" also '
          'means ZMW). Use the tools to answer questions about the '
          "user's real spending, budgets, and transactions — never guess "
          'a number you could look up. You may call multiple read tools in '
          'one turn. Call at most one propose_* tool per turn, and do not '
          'mix propose_* with read tools in the same turn. To log a new '
          'transaction or set a budget, call the matching propose_ tool; '
          'it only shows the user a confirmation card and saves nothing by '
          'itself, so propose confidently rather than asking permission '
          'first. Keep replies short — this is a chat, not a report.',
      'messages': messages,
    });

    http.StreamedResponse response;
    try {
      final request = http.Request('POST', Uri.parse(_endpoint))
        ..headers.addAll({
          'content-type': 'application/json',
          'x-api-key': apiKey,
          'anthropic-version': _apiVersion,
          'accept': 'text/event-stream',
        })
        ..body = body;
      response = await _http.send(request).timeout(const Duration(seconds: 45));
    } on Exception catch (error) {
      throw ChatException('Network error: $error');
    }

    if (response.statusCode != 200) {
      final errorBody = await response.stream.bytesToString();
      throw ChatException(
        'Anthropic API error ${response.statusCode}: $errorBody',
      );
    }

    try {
      return await _consumeSse(
        response.stream,
        onTextDelta: onTextDelta,
      ).timeout(const Duration(seconds: 45));
    } on TimeoutException {
      throw ChatException('Network error: timed out waiting for stream');
    }
  }

  /// Parses Anthropic SSE into a completed [ChatCompletion], optionally
  /// forwarding text deltas for progressive UI.
  Future<ChatCompletion> _consumeSse(
    Stream<List<int>> byteStream, {
    void Function(String delta)? onTextDelta,
  }) async {
    final blocks = <int, _OpenBlock>{};
    String? stopReason;
    final lineBuffer = StringBuffer();

    await for (final chunk in byteStream.transform(utf8.decoder)) {
      lineBuffer.write(chunk);
      var buffered = lineBuffer.toString();
      var newline = buffered.indexOf('\n');
      while (newline >= 0) {
        var line = buffered.substring(0, newline);
        buffered = buffered.substring(newline + 1);
        if (line.endsWith('\r')) {
          line = line.substring(0, line.length - 1);
        }

        if (line.startsWith('data:')) {
          final payload = line.substring(5).trimLeft();
          if (payload.isNotEmpty && payload != '[DONE]') {
            final event = jsonDecode(payload) as Map<String, dynamic>;
            _applySseEvent(
              event,
              blocks: blocks,
              onTextDelta: onTextDelta,
              setStopReason: (reason) => stopReason = reason,
            );
            if (event['type'] == 'message_stop') {
              lineBuffer
                ..clear()
                ..write(buffered);
              return ChatCompletion(
                content: [
                  for (final index in blocks.keys.toList()..sort())
                    blocks[index]!.toContentBlock(),
                ],
                stopReason: stopReason ?? 'end_turn',
              );
            }
            if (event['type'] == 'error') {
              final err = event['error'];
              throw ChatException('Anthropic stream error: $err');
            }
          }
        }

        newline = buffered.indexOf('\n');
      }
      lineBuffer
        ..clear()
        ..write(buffered);
    }

    if (blocks.isEmpty && stopReason == null) {
      throw ChatException('Anthropic stream ended without a completion');
    }

    return ChatCompletion(
      content: [
        for (final index in blocks.keys.toList()..sort())
          blocks[index]!.toContentBlock(),
      ],
      stopReason: stopReason ?? 'end_turn',
    );
  }

  void _applySseEvent(
    Map<String, dynamic> event, {
    required Map<int, _OpenBlock> blocks,
    required void Function(String delta)? onTextDelta,
    required void Function(String reason) setStopReason,
  }) {
    switch (event['type'] as String?) {
      case 'content_block_start':
        final index = event['index'] as int;
        final block = event['content_block'] as Map<String, dynamic>;
        final type = block['type'] as String?;
        if (type == 'text') {
          blocks[index] = _OpenBlock.text(block['text'] as String? ?? '');
        } else if (type == 'tool_use') {
          blocks[index] = _OpenBlock.toolUse(
            id: block['id'] as String? ?? '',
            name: block['name'] as String? ?? '',
          );
        }
      case 'content_block_delta':
        final index = event['index'] as int;
        final delta = event['delta'] as Map<String, dynamic>? ?? const {};
        final open = blocks[index];
        if (open == null) return;
        final deltaType = delta['type'] as String?;
        if (deltaType == 'text_delta') {
          final text = delta['text'] as String? ?? '';
          open.appendText(text);
          if (text.isNotEmpty) onTextDelta?.call(text);
        } else if (deltaType == 'input_json_delta') {
          open.appendJson(delta['partial_json'] as String? ?? '');
        }
      case 'message_delta':
        final delta = event['delta'] as Map<String, dynamic>? ?? const {};
        final reason = delta['stop_reason'] as String?;
        if (reason != null) setStopReason(reason);
      case 'message_start':
      case 'content_block_stop':
      case 'message_stop':
      case 'ping':
        break;
      case 'error':
        break;
    }
  }
}

class _OpenBlock {
  _OpenBlock._({
    required this.type,
    this.id,
    this.name,
    String text = '',
    String json = '',
  }) : _text = StringBuffer(text),
       _json = StringBuffer(json);

  factory _OpenBlock.text(String text) =>
      _OpenBlock._(type: 'text', text: text);

  factory _OpenBlock.toolUse({required String id, required String name}) =>
      _OpenBlock._(type: 'tool_use', id: id, name: name);

  final String type;
  final String? id;
  final String? name;
  final StringBuffer _text;
  final StringBuffer _json;

  void appendText(String delta) => _text.write(delta);

  void appendJson(String delta) => _json.write(delta);

  Map<String, dynamic> toContentBlock() {
    if (type == 'text') {
      return {'type': 'text', 'text': _text.toString()};
    }
    Map<String, dynamic> input;
    final raw = _json.toString();
    if (raw.isEmpty) {
      input = const {};
    } else {
      final decoded = jsonDecode(raw);
      input = decoded is Map<String, dynamic>
          ? decoded
          : const <String, dynamic>{};
    }
    return {
      'type': 'tool_use',
      'id': id,
      'name': name,
      'input': input,
    };
  }
}
