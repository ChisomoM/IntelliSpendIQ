import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intellispendiq/chat/cubit/cubit.dart';
import 'package:intellispendiq/chat/widgets/widgets.dart';
import 'package:intellispendiq/domain/models/chat_message.dart';
import 'package:intellispendiq/domain/services/finance_chat_service.dart';

class ChatPage extends StatelessWidget {
  const ChatPage({super.key});

  static Route<void> route() {
    return MaterialPageRoute<void>(builder: (_) => const ChatPage());
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ChatCubit(context.read<FinanceChatService>()),
      child: const ChatView(),
    );
  }
}

class ChatView extends StatefulWidget {
  const ChatView({super.key});

  @override
  State<ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<ChatView> {
  final _scrollController = ScrollController();
  late final TextEditingController _inputController;

  @override
  void initState() {
    super.initState();
    _inputController = TextEditingController(
      text: context.read<ChatCubit>().state.draft,
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _inputController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      unawaited(
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Assistant')),
      body: SafeArea(
        child: BlocConsumer<ChatCubit, ChatState>(
          listenWhen: (previous, current) =>
              previous.messages.length != current.messages.length,
          listener: (context, state) => _scrollToBottom(),
          builder: (context, state) {
            return Column(
              children: [
                Expanded(
                  child: state.isEmpty
                      ? const _ChatIntro()
                      : ListView(
                          controller: _scrollController,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          children: [
                            for (final message in state.messages)
                              _MessageBubble(message: message),
                            for (final action in state.pendingActions)
                              ProposedActionCard(
                                key: ValueKey(action.toolUseId),
                                action: action,
                                busy: state.status == ChatTurnStatus.working,
                                onConfirm: () => context
                                    .read<ChatCubit>()
                                    .confirmActionUnawaited(action),
                                onDismiss: () => context
                                    .read<ChatCubit>()
                                    .dismissActionUnawaited(action),
                              ),
                          ],
                        ),
                ),
                if (state.errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    child: Text(
                      state.errorMessage!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                _ChatInputBar(controller: _inputController),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ChatIntro extends StatelessWidget {
  const _ChatIntro();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.forum_outlined, size: 48),
            const SizedBox(height: 16),
            const Text(
              'Ask about your spending',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              '"How much did I spend on transport this month?" or '
              '"Set a 500 kwacha budget for food." Anything that changes '
              'your data shows up as a card to confirm first.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == ChatRole.user;
    final theme = Theme.of(context);

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.8,
        ),
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isUser
              ? theme.colorScheme.primaryContainer
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(message.text),
      ),
    );
  }
}

class _ChatInputBar extends StatelessWidget {
  const _ChatInputBar({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ChatCubit>();

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      child: BlocBuilder<ChatCubit, ChatState>(
        buildWhen: (previous, current) =>
            previous.status != current.status ||
            previous.draft != current.draft,
        builder: (context, state) {
          if (controller.text != state.draft) {
            controller.text = state.draft;
          }
          return Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.send,
                  decoration: const InputDecoration(
                    hintText: 'Ask or log a spend…',
                  ),
                  onChanged: cubit.draftChanged,
                  onSubmitted: (_) => cubit.sendUnawaited(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: state.status == ChatTurnStatus.working
                    ? null
                    : cubit.sendUnawaited,
                icon: state.status == ChatTurnStatus.working
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send),
              ),
            ],
          );
        },
      ),
    );
  }
}
