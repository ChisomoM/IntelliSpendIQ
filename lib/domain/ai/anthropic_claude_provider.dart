import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:intellispendiq/config/resolve_anthropic_api_key.dart';
import 'package:intellispendiq/data/secure/secure_store.dart';
import 'package:intellispendiq/domain/ai/ai_provider.dart';
import 'package:intellispendiq/domain/ai/pii.dart';
import 'package:intellispendiq/domain/ai/transaction_extraction.dart';

/// Claude via the Anthropic Messages API (D43).
///
/// Uses a forced strict tool call so the extraction always comes back as
/// schema-valid JSON. The API key lives in Keystore-backed secure
/// storage — acceptable for the private sideload phase; move to a thin
/// backend proxy before wider distribution (D42).
class AnthropicClaudeProvider implements AiProvider {
  AnthropicClaudeProvider({
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

  static const _toolName = 'record_transaction';

  static const Map<String, dynamic> _extractionTool = {
    'name': _toolName,
    'description':
        'Record a personal finance transaction extracted from a spoken '
        'expense description. Call this exactly once with your best '
        'extraction of the transaction described.',
    'strict': true,
    'input_schema': {
      'type': 'object',
      'properties': {
        'amount': {
          'type': ['number', 'null'],
          'description':
              'Transaction amount in major currency units (e.g. 50.0 for '
              'ZMW 50). Null if no amount was mentioned.',
        },
        'currency': {
          'type': 'string',
          'description': 'ISO-like currency code. Default ZMW.',
        },
        'direction': {
          'type': 'string',
          'enum': ['debit', 'credit'],
          'description': 'debit for money spent/sent, credit for received.',
        },
        'category_guess': {
          'type': ['string', 'null'],
          'description':
              'Best matching category from: Food, Transport, Airtime/Data, '
              'Transfers, Shopping, Bills, Income, Fees/Charges, Other. '
              'Null if unclear.',
        },
        'merchant_guess': {
          'type': ['string', 'null'],
          'description': 'Merchant / counterparty if mentioned.',
        },
        'payment_method': {
          'type': 'string',
          'enum': ['cash', 'mobile_money', 'card', 'bank'],
          'description': 'Payment method; default cash when unspecified.',
        },
        'date': {
          'type': ['string', 'null'],
          'description':
              'Transaction date as YYYY-MM-DD if a date/day was mentioned, '
              'else null (meaning today).',
        },
        'confidence': {
          'type': 'number',
          'description':
              'Your confidence 0.0-1.0 that the extraction is complete and '
              'correct. Below 0.85 sends the entry to human review.',
        },
      },
      'required': [
        'amount',
        'currency',
        'direction',
        'category_guess',
        'merchant_guess',
        'payment_method',
        'date',
        'confidence',
      ],
      'additionalProperties': false,
    },
  };

  @override
  Future<bool> get isConfigured async {
    final key = await resolveAnthropicApiKey(_secureStore);
    return key != null && key.isNotEmpty;
  }

  @override
  Future<TransactionExtraction> extractTransaction({
    required String transcript,
    String locale = 'en',
  }) async {
    final apiKey = await resolveAnthropicApiKey(_secureStore);
    if (apiKey == null || apiKey.isEmpty) {
      throw AiExtractionException('Anthropic API key not configured');
    }

    final cleanTranscript = stripPiiForLlm(transcript);
    final today = DateTime.now();
    final todayIso =
        '${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    final body = jsonEncode({
      'model': model,
      'max_tokens': 1024,
      // Server-side fallback: if safety classifiers decline, the request
      // is re-served by Anthropic's recommended fallback model instead
      // of failing outright.
      'fallbacks': 'default',
      'output_config': {'effort': 'low'},
      'system':
          'You extract personal finance transactions from short spoken '
          'expense notes in $locale, recorded in Zambia (currency ZMW, '
          '"K" also means ZMW). Today is $todayIso. Amounts spoken as '
          '"pin" may mean thousand kwacha in Zambian slang only when '
          'clearly used that way. Always call the $_toolName tool.',
      'messages': [
        {'role': 'user', 'content': cleanTranscript},
      ],
      'tools': [_extractionTool],
      'tool_choice': {'type': 'tool', 'name': _toolName},
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
      throw AiExtractionException('Network error: $error');
    }

    if (response.statusCode != 200) {
      throw AiExtractionException(
        'Anthropic API error ${response.statusCode}: ${response.body}',
      );
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    if (decoded['stop_reason'] == 'refusal') {
      throw AiExtractionException('Request declined by safety classifiers');
    }
    final content = (decoded['content'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    final toolUse = content.where(
      (block) => block['type'] == 'tool_use' && block['name'] == _toolName,
    );
    if (toolUse.isEmpty) {
      throw AiExtractionException('No tool_use block in response');
    }
    final input = toolUse.first['input'] as Map<String, dynamic>;
    return TransactionExtraction.fromJson(input);
  }
}
