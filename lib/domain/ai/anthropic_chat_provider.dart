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
    this.model = 'claude-sonnet-5',
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
  }) async {
    final apiKey = await resolveAnthropicApiKey(_secureStore);
    if (apiKey == null || apiKey.isEmpty) {
      throw ChatException('Anthropic API key not configured');
    }

    final body = jsonEncode({
      'model': model,
      'max_tokens': 2048,
      'fallbacks': 'default',
      'output_config': {'effort': 'medium'},
      'tools': tools,
      // One tool call per turn: the service's loop, and the pause/resume
      // handshake for actions awaiting human confirmation, both assume
      // at most one tool_use block per assistant message.
      'tool_choice': {'type': 'auto', 'disable_parallel_tool_use': true},
      'system':
          'You are the finance assistant inside IntelliSpendIQ, a personal '
          'expense tracker for a user in Zambia (currency ZMW; "K" also '
          'means ZMW). Use the tools to answer questions about the '
          "user's real spending, budgets, and transactions — never guess "
          'a number you could look up. To log a new transaction or set a '
          'budget, call the matching propose_ tool; it only shows the '
          'user a confirmation card and saves nothing by itself, so '
          'propose confidently rather than asking permission first. Keep '
          'replies short — this is a chat, not a report.',
      'messages': messages,
    });

    http.Response response;
    try {
      response = await _http
          .post(
            Uri.parse(_endpoint),
            headers: {
              'content-type': 'application/json',
              'x-api-key': apiKey,
              'anthropic-version': _apiVersion,
              'anthropic-beta': 'server-side-fallback-2026-07-01',
            },
            body: body,
          )
          .timeout(const Duration(seconds: 45));
    } on Exception catch (error) {
      throw ChatException('Network error: $error');
    }

    if (response.statusCode != 200) {
      throw ChatException(
        'Anthropic API error ${response.statusCode}: ${response.body}',
      );
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    if (decoded['stop_reason'] == 'refusal') {
      throw ChatException('Request declined by safety classifiers');
    }
    final content = (decoded['content'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    return ChatCompletion(
      content: content,
      stopReason: decoded['stop_reason'] as String? ?? 'end_turn',
    );
  }
}
