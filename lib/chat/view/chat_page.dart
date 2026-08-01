import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intellispendiq/chat/cubit/cubit.dart';
import 'package:intellispendiq/chat/widgets/widgets.dart';
import 'package:intellispendiq/design/design.dart';
import 'package:intellispendiq/domain/models/chat_message.dart';
import 'package:intellispendiq/domain/services/finance_chat_service.dart';

class ChatPage extends StatelessWidget {
  const ChatPage({this.initialPrompt, super.key});

  /// Pre-fills the input box, for the suggested openers on Home.
  ///
  /// Fills rather than sends: the user still presses send, so a
  /// mis-tapped suggestion costs nothing and the question can be
  /// edited first. That also keeps a tap on Home from silently
  /// spending an API call.
  final String? initialPrompt;

  static Route<void> route({String? initialPrompt}) {
    return MaterialPageRoute<void>(
      builder: (_) => ChatPage(initialPrompt: initialPrompt),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) {
        final cubit = ChatCubit(context.read<FinanceChatService>());
        if (initialPrompt != null) cubit.draftChanged(initialPrompt!);
        return cubit;
      },
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
                      horizontal: Space.gutter,
                      vertical: 4,
                    ),
                    child: Text(
                      state.errorMessage!,
                      style: AppTypography.metadata(
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
    return const EmptyState(
      icon: AppIcons.chat,
      title: 'Ask about your spending',
      message: '"How much did I spend on transport this month?" or '
          '"Set a 500 kwacha budget for food." Anything that changes '
          'your data shows up as a card to confirm first.',
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == ChatRole.user;
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.8,
        ),
        margin: const EdgeInsets.symmetric(
          horizontal: Space.gutter,
          vertical: 4,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: Space.x2,
          vertical: Space.x1,
        ),
        decoration: BoxDecoration(
          gradient: isUser ? AppGradients.action(Theme.of(context).brightness) : null,
          color: isUser
              ? null
              : (isDark ? colors.surfaceContainerLow : colors.surface),
          borderRadius: BorderRadius.circular(Radii.card),
          border: isUser || !isDark
              ? null
              : Border.all(color: colors.outlineVariant),
          boxShadow: isUser
              ? null
              : AppShadows.card(Theme.of(context).brightness),
        ),
        child: Text(
          message.text,
          style: AppTypography.body(
            color: isUser
                ? (isDark ? AppColors.ink900 : AppColors.paper)
                : colors.onSurface,
          ),
        ),
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
      padding: const EdgeInsets.fromLTRB(
        Space.x1,
        4,
        Space.x1,
        Space.x1,
      ),
      child: BlocBuilder<ChatCubit, ChatState>(
        buildWhen: (previous, current) =>
            previous.status != current.status ||
            previous.draft != current.draft,
        builder: (context, state) {
          if (controller.text != state.draft) {
            controller.text = state.draft;
          }
          final busy = state.status == ChatTurnStatus.working;

          return Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.send,
                  style: AppTypography.body(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Ask or log a spend…',
                  ),
                  onChanged: cubit.draftChanged,
                  onSubmitted: (_) => cubit.sendUnawaited(),
                ),
              ),
              const SizedBox(width: Space.x1),
              Container(
                width: Space.x6,
                height: Space.x6,
                decoration: BoxDecoration(
                  gradient: AppGradients.action(Theme.of(context).brightness),
                  shape: BoxShape.circle,
                ),
                child: Material(
                  color: Colors.transparent,
                  shape: const CircleBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: busy ? null : cubit.sendUnawaited,
                    child: Center(
                      child: busy
                          ? SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: _onAction(context),
                              ),
                            )
                          : AppIcon(
                              AppIcons.chevronRight,
                              size: 20,
                              color: _onAction(context),
                            ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// The action gradient runs dark violet in light mode and bright cyan
  /// in dark mode — [MoneyColors]-style ink pairing so the glyph on top
  /// clears contrast in both.
  Color _onAction(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? AppColors.ink900
        : AppColors.paper;
  }
}
