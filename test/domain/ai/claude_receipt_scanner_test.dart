import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intellispendiq/domain/ai/claude_receipt_scanner.dart';
import 'package:intellispendiq/domain/models/category.dart';
import 'package:intellispendiq/domain/models/enums.dart';

import '../../support/test_harness.dart';

void main() {
  late File photo;
  late FakeSecureStore secureStore;

  setUp(() async {
    final dir = await Directory.systemTemp.createTemp();
    photo = await File('${dir.path}/receipt.jpg').writeAsBytes([0]);
    secureStore = FakeSecureStore()..anthropicKey = 'test-key';
  });

  const categories = [
    Category(id: 'cat-food', name: 'Food'),
    Category(id: 'cat-restaurants', name: 'Restaurants', parentId: 'cat-food'),
    Category(id: 'cat-income', name: 'Salary', type: CategoryType.income),
  ];

  http.Response toolResponse(Map<String, dynamic> input) {
    return http.Response(
      jsonEncode({
        'content': [
          {'type': 'tool_use', 'name': 'extract_receipt', 'input': input},
        ],
      }),
      200,
    );
  }

  test('includes only expense categories in the prompt, by id', () async {
    Map<String, dynamic>? sentBody;
    final client = MockClient((request) async {
      sentBody = jsonDecode(request.body) as Map<String, dynamic>;
      return toolResponse({
        'merchant': 'Shoprite',
        'total': 45.0,
        'date': null,
        'items': <Map<String, dynamic>>[],
      });
    });
    final scanner = ClaudeReceiptScanner(
      secureStore: secureStore,
      httpClient: client,
    );

    await scanner.scanImage(photo.path, categories: categories);

    final promptText =
        (sentBody!['messages'] as List)[0]['content'][1]['text'] as String;
    expect(promptText, contains('cat-food: Food'));
    expect(promptText, contains('cat-restaurants: Food > Restaurants'));
    expect(promptText, isNot(contains('cat-income')));

    // No enum constraint — a large category list would otherwise bloat
    // the schema, and hallucinated ids are already rejected after the
    // fact in _resolveCategoryId.
    final tool = (sentBody!['tools'] as List).single as Map<String, dynamic>;
    final itemProperties =
        tool['input_schema']['properties']['items']['items']['properties']
            as Map<String, dynamic>;
    expect(itemProperties['category_id'], isNot(contains('enum')));
  });

  test('maps a valid suggested category id onto its line item', () async {
    final client = MockClient(
      (request) async => toolResponse({
        'merchant': 'Shoprite',
        'total': 15.0,
        'date': null,
        'items': [
          {'name': 'Pizza', 'amount': 15.0, 'category_id': 'cat-restaurants'},
        ],
      }),
    );
    final scanner = ClaudeReceiptScanner(
      secureStore: secureStore,
      httpClient: client,
    );

    final result = await scanner.scanImage(
      photo.path,
      categories: categories,
    );

    expect(result.lineItems.single.categoryId, 'cat-restaurants');
  });

  test(
    'drops a category id Claude hallucinated outside the given list',
    () async {
      final client = MockClient(
        (request) async => toolResponse({
          'merchant': 'Shoprite',
          'total': 15.0,
          'date': null,
          'items': [
            {'name': 'Pizza', 'amount': 15.0, 'category_id': 'made-up-id'},
          ],
        }),
      );
      final scanner = ClaudeReceiptScanner(
        secureStore: secureStore,
        httpClient: client,
      );

      final result = await scanner.scanImage(
        photo.path,
        categories: categories,
      );

      expect(result.lineItems.single.categoryId, isNull);
    },
  );

  test(
    'omits category_id from the schema when no categories are given',
    () async {
      Map<String, dynamic>? sentBody;
      final client = MockClient((request) async {
        sentBody = jsonDecode(request.body) as Map<String, dynamic>;
        return toolResponse({
          'merchant': 'Shoprite',
          'total': 15.0,
          'date': null,
          'items': [
            {'name': 'Pizza', 'amount': 15.0},
          ],
        });
      });
      final scanner = ClaudeReceiptScanner(
        secureStore: secureStore,
        httpClient: client,
      );

      final result = await scanner.scanImage(photo.path);

      final tool = (sentBody!['tools'] as List).single as Map<String, dynamic>;
      final itemProperties =
          tool['input_schema']['properties']['items']['items']['properties']
              as Map<String, dynamic>;
      expect(itemProperties.containsKey('category_id'), isFalse);
      expect(result.lineItems.single.categoryId, isNull);
    },
  );

  group('extractSummary: false (itemized scan)', () {
    test('omits merchant/total/date from the schema entirely', () async {
      Map<String, dynamic>? sentBody;
      final client = MockClient((request) async {
        sentBody = jsonDecode(request.body) as Map<String, dynamic>;
        return toolResponse({
          'items': [
            {'name': 'Bread', 'amount': 15.0},
          ],
        });
      });
      final scanner = ClaudeReceiptScanner(
        secureStore: secureStore,
        httpClient: client,
      );

      await scanner.scanImage(photo.path, extractSummary: false);

      final tool = (sentBody!['tools'] as List).single as Map<String, dynamic>;
      final properties =
          tool['input_schema']['properties'] as Map<String, dynamic>;
      expect(properties.containsKey('merchant'), isFalse);
      expect(properties.containsKey('total'), isFalse);
      expect(properties.containsKey('date'), isFalse);
      expect(properties.containsKey('items'), isTrue);
      final required = tool['input_schema']['required'] as List;
      expect(required, ['items']);
    });

    test(
      'ignores merchant/total/date even if the model returns them',
      () async {
        final client = MockClient(
          (request) async => toolResponse({
            'merchant': 'Shoprite',
            'total': 99.0,
            'date': '2026-01-01',
            'items': [
              {'name': 'Bread', 'amount': 15.0},
            ],
          }),
        );
        final scanner = ClaudeReceiptScanner(
          secureStore: secureStore,
          httpClient: client,
        );

        final result = await scanner.scanImage(
          photo.path,
          extractSummary: false,
        );

        expect(result.merchant, isNull);
        expect(result.amountMinor, isNull);
        expect(result.transactedAt, isNull);
        expect(result.lineItems.single.name, 'Bread');
      },
    );
  });

  test('throws when no API key is configured', () async {
    final scanner = ClaudeReceiptScanner(
      secureStore: FakeSecureStore(),
      httpClient: MockClient((_) async => http.Response('', 200)),
    );

    expect(() => scanner.scanImage(photo.path), throwsA(isA<Exception>()));
  });
}
