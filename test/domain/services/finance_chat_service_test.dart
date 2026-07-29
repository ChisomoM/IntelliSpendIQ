import 'package:flutter_test/flutter_test.dart';
import 'package:intellispendiq/domain/ai/chat_provider.dart';
import 'package:intellispendiq/domain/models/proposed_action.dart';

import '../../support/test_harness.dart';

Map<String, dynamic> _textBlock(String text) => {'type': 'text', 'text': text};

Map<String, dynamic> _toolUseBlock({
  required String id,
  required String name,
  required Map<String, dynamic> input,
}) => {'type': 'tool_use', 'id': id, 'name': name, 'input': input};

void main() {
  group('read-tool loop', () {
    test(
      'auto-continues after a read tool call until the model replies',
      () async {
        final provider = FakeChatProvider(
          responses: [
            ChatCompletion(
              content: [
                _toolUseBlock(
                  id: 'toolu_1',
                  name: 'get_spending_summary',
                  input: const {'period': null, 'category_name': null},
                ),
              ],
              stopReason: 'tool_use',
            ),
            ChatCompletion(
              content: [_textBlock("You haven't spent anything yet.")],
              stopReason: 'end_turn',
            ),
          ],
        );
        final services = await createTestServices(chatProvider: provider);
        addTearDown(services.dispose);

        final result = await services.financeChat.send(
          history: const [],
          userText: 'How much have I spent this month?',
        );

        expect(result.assistantText, "You haven't spent anything yet.");
        expect(result.pending, isEmpty);
        expect(
          provider.calls,
          hasLength(2),
          reason: 'the loop must call the provider again after the read tool',
        );

        final secondCallMessages = provider.calls[1];
        final toolResultMessage = secondCallMessages.last;
        expect(toolResultMessage['role'], 'user');
        final content = toolResultMessage['content'] as List<dynamic>;
        final toolResult = content.single as Map<String, dynamic>;
        expect(toolResult['type'], 'tool_result');
        expect(toolResult['tool_use_id'], 'toolu_1');
      },
    );
  });

  group('propose_add_transaction', () {
    test('pauses on a proposal without writing anything', () async {
      final provider = FakeChatProvider(
        responses: [
          ChatCompletion(
            content: [
              _toolUseBlock(
                id: 'toolu_add',
                name: 'propose_add_transaction',
                input: const {
                  'amount': 50.0,
                  'direction': 'debit',
                  'merchant': 'Shoprite',
                  'description': null,
                  'category_name': 'Transport',
                },
              ),
            ],
            stopReason: 'tool_use',
          ),
        ],
      );
      final services = await createTestServices(chatProvider: provider);
      addTearDown(services.dispose);

      final result = await services.financeChat.send(
        history: const [],
        userText: 'I spent 50 kwacha at Shoprite on transport',
      );

      expect(result.pending, hasLength(1));
      final action = result.pending.single as ProposedTransaction;
      expect(action.toolUseId, 'toolu_add');
      expect(action.amountMinor, 5000);
      expect(action.merchant, 'Shoprite');
      expect(action.categoryName, contains('Transport'));

      final recent = await services.transactions.watchRecent(limit: 10).first;
      expect(
        recent,
        isEmpty,
        reason: 'a proposal must not write until confirm() is called',
      );
    });

    test('confirm() writes the transaction and resumes the turn', () async {
      final provider = FakeChatProvider(
        responses: [
          ChatCompletion(
            content: [
              _toolUseBlock(
                id: 'toolu_add',
                name: 'propose_add_transaction',
                input: const {
                  'amount': 50.0,
                  'direction': 'debit',
                  'merchant': 'Shoprite',
                  'description': null,
                  'category_name': 'Transport',
                },
              ),
            ],
            stopReason: 'tool_use',
          ),
          ChatCompletion(
            content: [_textBlock('Logged it.')],
            stopReason: 'end_turn',
          ),
        ],
      );
      final services = await createTestServices(chatProvider: provider);
      addTearDown(services.dispose);

      final proposed = await services.financeChat.send(
        history: const [],
        userText: 'I spent 50 kwacha at Shoprite on transport',
      );
      final action = proposed.pending.single;

      final confirmed = await services.financeChat.confirm(
        history: proposed.wireHistory,
        action: action,
      );

      expect(confirmed.assistantText, 'Logged it.');
      expect(confirmed.pending, isEmpty);

      final recent = await services.transactions.watchRecent(limit: 10).first;
      expect(recent, hasLength(1));
      expect(recent.single.amountMinor, 5000);
      expect(recent.single.merchant, 'Shoprite');
    });

    test('dismiss() writes nothing but resumes the conversation', () async {
      final provider = FakeChatProvider(
        responses: [
          ChatCompletion(
            content: [
              _toolUseBlock(
                id: 'toolu_add',
                name: 'propose_add_transaction',
                input: const {
                  'amount': 50.0,
                  'direction': 'debit',
                  'merchant': 'Shoprite',
                  'description': null,
                  'category_name': 'Transport',
                },
              ),
            ],
            stopReason: 'tool_use',
          ),
          ChatCompletion(
            content: [_textBlock('No problem, not logged.')],
            stopReason: 'end_turn',
          ),
        ],
      );
      final services = await createTestServices(chatProvider: provider);
      addTearDown(services.dispose);

      final proposed = await services.financeChat.send(
        history: const [],
        userText: 'I spent 50 kwacha at Shoprite on transport',
      );
      final action = proposed.pending.single;

      final dismissed = await services.financeChat.dismiss(
        history: proposed.wireHistory,
        action: action,
      );

      expect(dismissed.assistantText, 'No problem, not logged.');
      expect(dismissed.pending, isEmpty);

      final recent = await services.transactions.watchRecent(limit: 10).first;
      expect(recent, isEmpty);

      final toolResultMessage = provider.calls[1].last;
      final content = toolResultMessage['content'] as List<dynamic>;
      final toolResult = content.single as Map<String, dynamic>;
      expect(toolResult['content'] as String, contains('"confirmed":false'));
    });
  });

  group('propose_set_budget', () {
    test(
      'an unknown category becomes an error tool_result, not a broken card',
      () async {
        final provider = FakeChatProvider(
          responses: [
            ChatCompletion(
              content: [
                _toolUseBlock(
                  id: 'toolu_budget',
                  name: 'propose_set_budget',
                  input: const {
                    'category_name': 'Not A Real Category',
                    'amount': 500.0,
                    'period': null,
                  },
                ),
              ],
              stopReason: 'tool_use',
            ),
            ChatCompletion(
              content: [
                _textBlock('Which category did you mean — Food or Shopping?'),
              ],
              stopReason: 'end_turn',
            ),
          ],
        );
        final services = await createTestServices(chatProvider: provider);
        addTearDown(services.dispose);

        final result = await services.financeChat.send(
          history: const [],
          userText: 'Set a 500 kwacha budget for made-up stuff',
        );

        expect(result.pending, isEmpty);
        expect(
          result.assistantText,
          'Which category did you mean — Food or Shopping?',
        );
        expect(
          provider.calls,
          hasLength(2),
          reason: 'the loop must retry after the error tool_result',
        );

        final retryMessages = provider.calls[1];
        final toolResultMessage = retryMessages.last;
        final content = toolResultMessage['content'] as List<dynamic>;
        final toolResult = content.single as Map<String, dynamic>;
        expect(toolResult['content'] as String, contains('error'));
      },
    );

    test('confirm() saves the budget once the category resolves', () async {
      final provider = FakeChatProvider(
        responses: [
          ChatCompletion(
            content: [
              _toolUseBlock(
                id: 'toolu_budget',
                name: 'propose_set_budget',
                input: const {
                  'category_name': 'Food',
                  'amount': 500.0,
                  'period': '2026-07',
                },
              ),
            ],
            stopReason: 'tool_use',
          ),
          ChatCompletion(
            content: [_textBlock('Budget set.')],
            stopReason: 'end_turn',
          ),
        ],
      );
      final services = await createTestServices(chatProvider: provider);
      addTearDown(services.dispose);

      final proposed = await services.financeChat.send(
        history: const [],
        userText: 'Set a 500 kwacha food budget for July',
      );
      final action = proposed.pending.single as ProposedBudget;
      expect(action.period, '2026-07');
      expect(action.amountMinor, 50000);

      final confirmed = await services.financeChat.confirm(
        history: proposed.wireHistory,
        action: action,
      );
      expect(confirmed.assistantText, 'Budget set.');

      final budgets = await services.budgets.getForPeriod('2026-07');
      expect(budgets, hasLength(1));
      expect(budgets.single.amountMinor, 50000);
    });
  });
}
