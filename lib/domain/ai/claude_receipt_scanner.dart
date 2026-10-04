import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:intellispendiq/config/resolve_anthropic_api_key.dart';
import 'package:intellispendiq/core/money.dart';
import 'package:intellispendiq/data/secure/secure_store.dart';
import 'package:intellispendiq/domain/ai/anthropic_claude_provider.dart';
import 'package:intellispendiq/domain/ai/transaction_extraction.dart';
import 'package:intellispendiq/domain/models/category.dart';
import 'package:intellispendiq/domain/models/enums.dart';
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
  static const _logName = 'receipt_scan';

  final SecureStore _secureStore;
  final http.Client _http;

  /// Scans [imagePath] for a receipt's contents. [categories] — normally
  /// the app's whole category list — is filtered down to expense
  /// categories and offered to Claude so it can suggest one per item
  /// (a receipt is always an expense); pass an empty list to skip
  /// category suggestions entirely.
  ///
  /// [extractSummary] controls whether merchant/total/date are asked
  /// for at all — the single-entry "Scan a receipt" flow needs them
  /// (it has no items to show), the itemized flow only needs items
  /// (merchant/date are typed by hand on that screen) and dropping
  /// them keeps the schema smaller and the call faster.
  Future<ReceiptScanResult> scanImage(
    String imagePath, {
    List<Category> categories = const [],
    bool extractSummary = true,
  }) async {
    log(
      'scanImage start: file=${p.basename(imagePath)} '
      'categoriesGiven=${categories.length} extractSummary=$extractSummary',
      name: _logName,
    );

    final apiKey = await resolveAnthropicApiKey(_secureStore);
    if (apiKey == null || apiKey.isEmpty) {
      log('scanImage abort: no API key configured', name: _logName);
      throw AiExtractionException('Anthropic API key not configured');
    }

    final mediaType = _mediaTypeFor(imagePath);
    if (mediaType == null) {
      log(
        'scanImage abort: unsupported image type '
        '${p.extension(imagePath)}',
        name: _logName,
      );
      throw AiExtractionException(
        'Unsupported image type: ${p.extension(imagePath)}',
      );
    }
    final bytes = await File(imagePath).readAsBytes();
    final base64Image = base64Encode(bytes);

    final expenseCategories = categories
        .where((c) => c.type == CategoryType.expense)
        .toList();
    final categoriesById = {for (final c in categories) c.id: c};
    final categoryIds = [for (final c in expenseCategories) c.id];
    log(
      'scanImage request: bytes=${bytes.length} mediaType=$mediaType '
      'expenseCategories=${categoryIds.length}',
      name: _logName,
    );

    final body = jsonEncode({
      'model': _model,
      'max_tokens': 1024,
      'system':
          'You read photographed retail receipts for a Zambian personal '
          'finance app (currency ZMW, "K" also means ZMW). '
          '${extractSummary ? 'Extract the merchant, the grand total '
                    'actually paid, the purchase date, and every '
                    'individually priced item' : 'Extract every individually '
                    'priced item on the receipt'} — never guess a value you '
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
              'text':
                  "Extract this receipt's contents."
                  '${_categoryPrompt(expenseCategories, categoriesById)}',
            },
          ],
        },
      ],
      'tools': [_buildExtractionTool(categoryIds, extractSummary)],
      'tool_choice': {'type': 'tool', 'name': _toolName},
    });

    http.Response response;
    final stopwatch = Stopwatch()..start();
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
    } on Exception catch (error, stackTrace) {
      log(
        'scanImage network error after ${stopwatch.elapsedMilliseconds}ms',
        name: _logName,
        error: error,
        stackTrace: stackTrace,
      );
      throw AiExtractionException('Network error: $error');
    }
    log(
      'scanImage response: status=${response.statusCode} '
      'elapsedMs=${stopwatch.elapsedMilliseconds}',
      name: _logName,
    );

    // The literal, un-parsed response body — logged unconditionally
    // (success or not) so a wrong extraction can always be checked
    // against exactly what the API sent back, not a summary of it.
    log('scanImage raw response body: ${response.body}', name: _logName);

    if (response.statusCode != 200) {
      throw AiExtractionException(
        'Anthropic API error ${response.statusCode}: ${response.body}',
      );
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    if (decoded['stop_reason'] == 'refusal') {
      log('scanImage refused by safety classifiers', name: _logName);
      throw AiExtractionException('Request declined by safety classifiers');
    }
    final content = (decoded['content'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    final toolUse = content.where(
      (block) => block['type'] == 'tool_use' && block['name'] == _toolName,
    );
    if (toolUse.isEmpty) {
      log(
        'scanImage no tool_use block: stop_reason=${decoded['stop_reason']}',
        name: _logName,
      );
      throw AiExtractionException('No tool_use block in response');
    }

    final input = toolUse.first['input'] as Map<String, dynamic>;
    // Raw, exactly as Claude returned it — before any of the parsing/
    // validation below touches it. A category_id that gets dropped as
    // a hallucination, an odd date format, an item this build's schema
    // doesn't expect: all show up here as Claude actually wrote them,
    // not as whatever the parsed ReceiptScanResult made of them.
    log('scanImage raw tool input: ${jsonEncode(input)}', name: _logName);

    final result = _resultFromToolInput(
      input,
      rawText: response.body,
      validCategoryIds: categoryIds.toSet(),
      extractSummary: extractSummary,
    );
    log(
      'scanImage parsed: merchant=${result.merchant} '
      'amountMinor=${result.amountMinor} date=${result.transactedAt} '
      'items=${result.lineItems.length} '
      'itemsWithCategory='
      '${result.lineItems.where((i) => i.categoryId != null).length}',
      name: _logName,
    );
    return result;
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

  /// `id: Name` for a top-level category, `id: Parent > Name` for a
  /// subcategory — plain enough for the model to line up against what
  /// it reads on the receipt without needing the rest of the app's
  /// category-hierarchy code.
  static String _categoryPrompt(
    List<Category> expenseCategories,
    Map<String, Category> categoriesById,
  ) {
    if (expenseCategories.isEmpty) return '';
    final lines = [
      for (final c in expenseCategories)
        '${c.id}: ${c.parentId == null ? c.displayName : '${categoriesById[c.parentId]?.displayName ?? '?'} > ${c.displayName}'}',
    ];
    return '\n\nAvailable categories (id: name) — for each item, suggest '
        'the id of the closest match, or null if none fit. Never invent '
        'an id that is not in this list:\n${lines.join('\n')}';
  }

  static Map<String, dynamic> _buildExtractionTool(
    List<String> categoryIds,
    bool extractSummary,
  ) {
    return {
      'name': _toolName,
      'description':
          'Record the structured contents of a photographed receipt. '
          'Call this exactly once with your best reading of the photo.',
      'input_schema': {
        'type': 'object',
        'properties': {
          if (extractSummary) ...{
            'merchant': {
              'type': ['string', 'null'],
              'description': 'Store or merchant name, or null if illegible.',
            },
            'total': {
              'type': ['number', 'null'],
              'description':
                  'The grand total actually charged, in major currency '
                  'units (e.g. 45.0 for K45.00) — not a subtotal. Null if '
                  'unclear.',
            },
            'date': {
              'type': ['string', 'null'],
              'description':
                  'Purchase date as YYYY-MM-DD if printed on the receipt, '
                  'else null.',
            },
          },
          'items': {
            'type': 'array',
            'description':
                'Every individually priced product/service line '
                'actually purchased — not the subtotal, tax, tip, '
                'tender, change, or total lines.',
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
                if (categoryIds.isNotEmpty)
                  'category_id': {
                    'type': ['string', 'null'],
                    'description':
                        "This item's best-matching category id, copied "
                        'exactly from the list given in the prompt, or '
                        'null if none fit. Never invent an id.',
                  },
              },
              'required': ['name', 'amount'],
            },
          },
        },
        'required': [
          if (extractSummary) ...['merchant', 'total', 'date'],
          'items',
        ],
      },
    };
  }

  static ReceiptScanResult _resultFromToolInput(
    Map<String, dynamic> input, {
    required String rawText,
    required Set<String> validCategoryIds,
    required bool extractSummary,
  }) {
    final merchant = extractSummary
        ? (input['merchant'] as String?)?.trim()
        : null;
    final total = extractSummary ? input['total'] : null;
    final date = extractSummary ? input['date'] as String? : null;
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
                  categoryId: _resolveCategoryId(
                    raw['category_id'],
                    validCategoryIds,
                  ),
                ),
      ],
    );
  }

  /// Never trust an id Claude didn't actually offer — a hallucinated
  /// one would otherwise silently fail to resolve to a category later.
  static String? _resolveCategoryId(
    Object? categoryId,
    Set<String> validCategoryIds,
  ) {
    if (categoryId == null) return null;
    if (validCategoryIds.contains(categoryId)) return categoryId as String;
    log(
      'scanImage dropped hallucinated category_id: $categoryId',
      name: _logName,
    );
    return null;
  }
}
