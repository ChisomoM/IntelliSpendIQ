import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:intellispendiq/config/resolve_anthropic_api_key.dart';
import 'package:intellispendiq/core/money.dart';
import 'package:intellispendiq/data/secure/secure_store.dart';
import 'package:intellispendiq/domain/ai/anthropic_claude_provider.dart';
import 'package:intellispendiq/domain/ai/transaction_extraction.dart';
import 'package:intellispendiq/domain/services/receipt_scanner.dart';
import 'package:path/path.dart' as p;

/// Reads a receipt photo with Claude's vision (D43-style Anthropic
/// Messages API call, matching [AnthropicClaudeProvider]'s pattern) —
/// merchant, total, date, and every individual priced line item, in one
/// call, using a forced tool call so the result always comes back as
/// schema-valid JSON.
///
/// Same public shape as [ReceiptScanner] (`scanImage`/`dispose`), so it's
/// a drop-in replacement wherever that was used — see the "UNUSED" note
/// on [ReceiptScanner] for why the on-device version was set aside
/// rather than kept as the active path.
class ClaudeReceiptScanner {
  ClaudeReceiptScanner({
    required SecureStore secureStore,
    http.Client? httpClient,
  }) : _secureStore = secureStore,
       _http = httpClient ?? http.Client();

  static const _endpoint = 'https://api.anthropic.com/v1/messages';
  static const _apiVersion = '2023-06-01';
  static const _model = 'claude-haiku-4-5';
  static const _toolName = 'extract_receipt';

  final SecureStore _secureStore;
  final http.Client _http;

  static const Map<String, dynamic> _extractionTool = {
    'name': _toolName,
    'description':
        'Record the structured contents of a photographed receipt. Call '
        'this exactly once with your best reading of the photo.',
    'input_schema': {
      'type': 'object',
      'properties': {
        'merchant': {
          'type': ['string', 'null'],
          'description': 'Store or merchant name, or null if illegible.',
        },
        'total': {
          'type': ['number', 'null'],
          'description':
              'The grand total actually charged, in major currency units '
              '(e.g. 45.0 for K45.00) — not a subtotal. Null if unclear.',
        },
        'date': {
          'type': ['string', 'null'],
          'description':
              'Purchase date as YYYY-MM-DD if printed on the receipt, '
              'else null.',
        },
        'items': {
          'type': 'array',
          'description':
              'Every individually priced product/service line actually '
              'purchased — not the subtotal, tax, tip, tender, change, or '
              'total lines.',
          'items': {
            'type': 'object',
            'properties': {
              'name': {
                'type': 'string',
                'description': 'The item as printed, cleaned up if garbled.',
              },
              'amount': {
                'type': 'number',
                'description': "That item's price in major currency units.",
              },
            },
            'required': ['name', 'amount'],
          },
        },
      },
      'required': ['merchant', 'total', 'date', 'items'],
    },
  };

  Future<ReceiptScanResult> scanImage(String imagePath) async {
    final apiKey = await resolveAnthropicApiKey(_secureStore);
    if (apiKey == null || apiKey.isEmpty) {
      throw AiExtractionException('Anthropic API key not configured');
    }

    final mediaType = _mediaTypeFor(imagePath);
    if (mediaType == null) {
      throw AiExtractionException(
        'Unsupported image type: ${p.extension(imagePath)}',
      );
    }
    final bytes = await File(imagePath).readAsBytes();
    final base64Image = base64Encode(bytes);

    final body = jsonEncode({
      'model': _model,
      'max_tokens': 1024,
      'system':
          'You read photographed retail receipts for a Zambian personal '
          'finance app (currency ZMW, "K" also means ZMW). Extract the '
          'merchant, the grand total actually paid, the purchase date, '
          'and every individual priced item — never guess a value you '
          "can't actually read; use null instead. Always call the "
          '$_toolName tool.',
      'messages': [
        {
          'role': 'user',
          'content': [
            {
              'type': 'image',
              'source': {
                'type': 'base64',
                'media_type': mediaType,
                'data': base64Image,
              },
            },
            {
              'type': 'text',
              'text': "Extract this receipt's contents.",
            },
          ],
        },
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
    return _resultFromToolInput(input, rawText: response.body);
  }

  Future<void> dispose() async => _http.close();

  static String? _mediaTypeFor(String path) {
    switch (p.extension(path).toLowerCase()) {
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.png':
        return 'image/png';
      case '.webp':
        return 'image/webp';
      case '.gif':
        return 'image/gif';
      default:
        return null;
    }
  }

  static ReceiptScanResult _resultFromToolInput(
    Map<String, dynamic> input, {
    required String rawText,
  }) {
    final merchant = (input['merchant'] as String?)?.trim();
    final total = input['total'];
    final date = input['date'] as String?;
    final itemsRaw = (input['items'] as List<dynamic>?) ?? const [];

    return ReceiptScanResult(
      rawText: rawText,
      merchant: merchant == null || merchant.isEmpty ? null : merchant,
      amountMinor: total is num
          ? Money.minorFromDouble(total.toDouble())
          : null,
      transactedAt: date == null ? null : DateTime.tryParse(date),
      lineItems: [
        for (final raw in itemsRaw)
          if (raw is Map<String, dynamic>)
            if ((raw['name'] as String?)?.trim().isNotEmpty ?? false)
              if (raw['amount'] is num && (raw['amount'] as num) > 0)
                ReceiptLineItem(
                  name: (raw['name']! as String).trim(),
                  amountMinor: Money.minorFromDouble(
                    (raw['amount']! as num).toDouble(),
                  ),
                ),
      ],
    );
  }
}
