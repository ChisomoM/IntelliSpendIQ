import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intellispendiq/app/app_services.dart';
import 'package:intellispendiq/chat/chat.dart';
import 'package:intellispendiq/domain/ai/chat_provider.dart';
import 'package:intellispendiq/domain/models/chat_message.dart';
import 'package:intellispendiq/domain/models/proposed_action.dart';

import '../../support/test_harness.dart';

Map<String, dynamic> _textBlock(String text) => {'type': 'text', 'text': text};

Map<String, dynamic> _toolUseBlock({
  required String id,
  required String name,
  required Map<String, dynamic> input,
}) => {'type': 'tool_use', 'id': id, 'name': name, 'input': input};

void main() {
  late AppServices services;

  Future<ChatCubit> cubitWith(FakeChatProvider provider) async {
    services = await createTestServices(chatProvider: provider);
    addTearDown(services.dispose);
    return ChatCubit(services.financeChat);
  }

  group('ChatCubit', () {
    test('draftChanged updates the draft', () async {
      final cubit = await cubitWith(FakeChatProvider());
      addTearDown(cubit.close);

      cubit.draftChanged('how much on food?');

      expect(cubit.state.draft, 'how much on food?');
    });

    test('ignores sending an empty or whitespace-only draft', () async {
      final cubit = await cubitWith(FakeChatProvider());
      addTearDown(cubit.close);

      cubit.draftChanged('   ');
      await cubit.send();

      expect(cubit.state.messages, isEmpty);
      expect(cubit.state.status, ChatTurnStatus.idle);
    });

    test('send() appends the reply and clears the draft', () async {
      final cubit = await cubitWith(
        FakeChatProvider(
          responses: [
            ChatCompletion(
              content: [_textBlock('Nothing logged yet this month.')],
              stopReason: 'end_turn',
            ),
          ],
        ),
      );
      addTearDown(cubit.close);

      cubit.draftChanged('how much have I spent?');
      await cubit.send();

      expect(cubit.state.draft, isEmpty);
      expect(cubit.state.status, ChatTurnStatus.idle);
      expect(cubit.state.messages, [
        const ChatMessage(
          role: ChatRole.user,
          text: 'how much have I spent?',
        ),
        const ChatMessage(
          role: ChatRole.assistant,
          text: 'Nothing logged yet this month.',
        ),
      ]);
    });

    test('send() surfaces a proposed action as a pending card', () async {
      final cubit = await cubitWith(
        FakeChatProvider(
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
        ),
      );
      addTearDown(cubit.close);

      cubit.draftChanged('spent 50 at shoprite');
      await cubit.send();

      expect(cubit.state.pendingActions, hasLength(1));
      expect(cubit.state.pendingActions.single, isA<ProposedTransaction>());
    });

    test('confirmAction() resolves the card and appends the reply', () async {
      final cubit = await cubitWith(
        FakeChatProvider(
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
        ),
      );
      addTearDown(cubit.close);

      cubit.draftChanged('spent 50 at shoprite');
      await cubit.send();
      final action = cubit.state.pendingActions.single;

      await cubit.confirmAction(action);

      expect(cubit.state.pendingActions, isEmpty);
      expect(cubit.state.messages.last.text, 'Logged it.');
      final recent = await services.transactions.watchRecent(limit: 10).first;
      expect(recent, hasLength(1));
    });

    test('dismissAction() clears the card without writing anything', () async {
      final cubit = await cubitWith(
        FakeChatProvider(
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
              content: [_textBlock('Not logged.')],
              stopReason: 'end_turn',
            ),
          ],
        ),
      );
      addTearDown(cubit.close);

      cubit.draftChanged('spent 50 at shoprite');
      await cubit.send();
      final action = cubit.state.pendingActions.single;

      await cubit.dismissAction(action);

      expect(cubit.state.pendingActions, isEmpty);
      final recent = await services.transactions.watchRecent(limit: 10).first;
      expect(recent, isEmpty);
    });

    test('a provider failure surfaces an error message', () async {
      final cubit = await cubitWith(FakeChatProvider());
      addTearDown(cubit.close);

      cubit.draftChanged('how much on food?');
      await cubit.send();

      expect(cubit.state.status, ChatTurnStatus.idle);
      expect(cubit.state.errorMessage, isNotNull);
    });

    blocTest<ChatCubit, ChatState>(
      'emits working before the reply',
      build: () => ChatCubit(services.financeChat),
      setUp: () async {
        services = await createTestServices(
          chatProvider: FakeChatProvider(
            responses: [
              ChatCompletion(
                content: [_textBlock('Sure, go ahead.')],
                stopReason: 'end_turn',
              ),
            ],
          ),
        );
        addTearDown(services.dispose);
      },
      act: (cubit) async {
        cubit.draftChanged('hi');
        await cubit.send();
      },
      expect: () => [
        isA<ChatState>().having((s) => s.draft, 'draft', 'hi'),
        isA<ChatState>()
            .having((s) => s.status, 'status', ChatTurnStatus.working)
            .having((s) => s.messages, 'messages', hasLength(1)),
        isA<ChatState>()
            .having((s) => s.status, 'status', ChatTurnStatus.idle)
            .having((s) => s.messages, 'messages', hasLength(2)),
      ],
    );
  });
}
