import 'dart:convert';

import 'package:intellispendiq/core/ids.dart';
import 'package:intellispendiq/core/money.dart';
import 'package:intellispendiq/core/time.dart';
import 'package:intellispendiq/data/repositories/account_repository.dart';
import 'package:intellispendiq/data/repositories/budget_period_repository.dart';
import 'package:intellispendiq/data/repositories/category_repository.dart';
import 'package:intellispendiq/data/repositories/transaction_repository.dart';
import 'package:intellispendiq/domain/ai/chat_provider.dart';
import 'package:intellispendiq/domain/ai/pii.dart';
import 'package:intellispendiq/domain/models/enums.dart';
import 'package:intellispendiq/domain/models/proposed_action.dart';
import 'package:intellispendiq/domain/models/transaction_draft.dart';

/// What one turn of the chat produced.
class ChatTurnResult {
  const ChatTurnResult({
    required this.assistantText,
    required this.pending,
    required this.wireHistory,
    this.deferredToolResults = const [],
  });

  /// Text to show as the assistant's reply. Can be empty when the turn
  /// ended on a proposal with nothing said beforehand.
  final String assistantText;

  /// Awaiting a human decision before the conversation can continue.
  /// Empty when the turn ended in ordinary conversation.
  final List<ProposedAction> pending;

  /// The full Anthropic-format message history so far, including the
  /// still-unresolved tool_use turn when `pending` is non-empty. The
  /// caller must hold onto this and pass it back to `confirm` or
  /// `dismiss` — there is nowhere else it is stored.
  final List<Map<String, dynamic>> wireHistory;

  /// Tool-result content blocks for sibling tools already executed in
  /// the same assistant turn as a paused propose_* call. Must be sent
  /// together with the propose tool_result when the user confirms or
  /// dismisses.
  final List<Map<String, dynamic>> deferredToolResults;
}

/// Read-only analysis plus propose-and-confirm actions over the user's
/// real financial data, backed by Claude tool use.
///
/// The most important property of this class: **only the read tools
/// ever touch a repository write method.** A propose_* tool call is
/// resolved into a [ProposedAction] and the tool-use loop pauses —
/// nothing is written until [confirm] is called, which happens only
/// from a human tapping a confirmation card. This mirrors the app's
/// existing rule that auto-save requires either a deterministic parse
/// or high voice confidence; free-form chat gets neither, so it never
/// auto-saves at all.
class FinanceChatService {
  FinanceChatService({
    required ChatProvider provider,
    required TransactionRepository transactions,
    required AccountRepository accounts,
    required CategoryRepository categories,
    required BudgetPeriodRepository budgetPeriods,
  }) : _provider = provider,
       _transactions = transactions,
       _accounts = accounts,
       _categories = categories,
       _budgetPeriods = budgetPeriods;

  final ChatProvider _provider;
  final TransactionRepository _transactions;
  final AccountRepository _accounts;
  final CategoryRepository _categories;
  final BudgetPeriodRepository _budgetPeriods;

  static const _proposeAddTransaction = 'propose_add_transaction';
  static const _proposeSetBudget = 'propose_set_budget';
  static const _maxToolRounds = 4;
  static const _maxWireMessages = 24;

  Future<bool> get isConfigured => _provider.isConfigured;

  /// Starts or continues the conversation with a new user message.
  Future<ChatTurnResult> send({
    required List<Map<String, dynamic>> history,
    required String userText,
    void Function(String partialText)? onPartialText,
  }) {
    return _runLoop(
      [
        ...history,
        {'role': 'user', 'content': stripPiiForLlm(userText)},
      ],
      onPartialText: onPartialText,
    );
  }

  /// Applies a previously proposed action, then resumes the paused
  /// tool-use turn so Claude can acknowledge it.
  Future<ChatTurnResult> confirm({
    required List<Map<String, dynamic>> history,
    required ProposedAction action,
    List<Map<String, dynamic>> deferredToolResults = const [],
    void Function(String partialText)? onPartialText,
  }) async {
    final outcome = await _applyAction(action);
    return _runLoop(
      [
        ...history,
        _toolResultsMessage([
          ...deferredToolResults,
          _toolResultBlock(action.toolUseId, {
            'confirmed': true,
            'result': outcome,
          }),
        ]),
      ],
      onPartialText: onPartialText,
    );
  }

  /// Declines a previously proposed action without writing anything.
  Future<ChatTurnResult> dismiss({
    required List<Map<String, dynamic>> history,
    required ProposedAction action,
    List<Map<String, dynamic>> deferredToolResults = const [],
    void Function(String partialText)? onPartialText,
  }) {
    return _runLoop(
      [
        ...history,
        _toolResultsMessage([
          ...deferredToolResults,
          _toolResultBlock(action.toolUseId, {'confirmed': false}),
        ]),
      ],
      onPartialText: onPartialText,
    );
  }

  Future<ChatTurnResult> _runLoop(
    List<Map<String, dynamic>> messages, {
    void Function(String partialText)? onPartialText,
  }) async {
    var current = _trimWireHistory(messages);
    var rounds = 0;
    final streamed = StringBuffer();

    while (true) {
      rounds++;
      if (rounds > _maxToolRounds) {
        return ChatTurnResult(
          assistantText:
              'That took too many steps — try asking a simpler question.',
          pending: const [],
          wireHistory: current,
        );
      }

      streamed.clear();
      onPartialText?.call('');
      final completion = await _provider.complete(
        messages: current,
        tools: _tools,
        onTextDelta: onPartialText == null
            ? null
            : (delta) {
                streamed.write(delta);
                onPartialText(streamed.toString());
              },
      );
      current = [
        ...current,
        {'role': 'assistant', 'content': completion.content},
      ];

      final text = completion.content
          .where((block) => block['type'] == 'text')
          .map((block) => block['text'] as String)
          .join('\n')
          .trim();

      final toolUses = completion.content
          .where((block) => block['type'] == 'tool_use')
          .toList(growable: false);

      if (completion.stopReason != 'tool_use' || toolUses.isEmpty) {
        return ChatTurnResult(
          assistantText: text,
          pending: const [],
          wireHistory: current,
        );
      }

      final readUses = <Map<String, dynamic>>[];
      final proposeUses = <Map<String, dynamic>>[];
      for (final toolUse in toolUses) {
        final name = toolUse['name'] as String;
        if (name == _proposeAddTransaction || name == _proposeSetBudget) {
          proposeUses.add(toolUse);
        } else {
          readUses.add(toolUse);
        }
      }

      final readBlocks = await Future.wait([
        for (final toolUse in readUses)
          _executeReadTool(
            toolUse['name'] as String,
            (toolUse['input'] as Map<String, dynamic>?) ?? const {},
          ).then(
            (result) => _toolResultBlock(toolUse['id'] as String, result),
          ),
      ]);

      final pending = <ProposedAction>[];
      final proposeBlocks = <Map<String, dynamic>>[];
      for (final toolUse in proposeUses) {
        final name = toolUse['name'] as String;
        final toolUseId = toolUse['id'] as String;
        final input = (toolUse['input'] as Map<String, dynamic>?) ?? const {};
        final resolved = name == _proposeAddTransaction
            ? await _resolveAddTransaction(toolUseId, input)
            : await _resolveSetBudget(toolUseId, input);

        if (resolved == null) {
          proposeBlocks.add(
            _toolResultBlock(toolUseId, {
              'error':
                  'Could not find a category matching that name. Ask the '
                  'user which category to use, or list categories first.',
            }),
          );
        } else {
          pending.add(resolved);
        }
      }

      if (pending.isNotEmpty) {
        // Pause for human confirmation. Already-finished sibling tool
        // results (reads + failed proposes) travel with the later
        // confirm/dismiss so Anthropic still sees one result per tool_use.
        return ChatTurnResult(
          assistantText: text,
          pending: pending,
          wireHistory: current,
          deferredToolResults: [...readBlocks, ...proposeBlocks],
        );
      }

      current = [
        ...current,
        _toolResultsMessage([...readBlocks, ...proposeBlocks]),
      ];
    }
  }

  /// Keeps recent turns so chat latency does not grow with the session.
  /// Preserves tool_use / tool_result pairing by dropping from the front
  /// in whole messages only.
  List<Map<String, dynamic>> _trimWireHistory(
    List<Map<String, dynamic>> messages,
  ) {
    if (messages.length <= _maxWireMessages) return messages;
    return messages.sublist(messages.length - _maxWireMessages);
  }

  Future<String> _applyAction(ProposedAction action) => switch (action) {
    ProposedTransaction() => _confirmTransaction(action),
    ProposedBudget() => _confirmBudget(action),
  };

  Future<String> _confirmTransaction(ProposedTransaction action) async {
    final draft = TransactionDraft(
      amountMinor: action.amountMinor,
      direction: action.direction,
      source: TxSource.manual,
      transactedAt: DateTime.now(),
      merchant: action.merchant,
      description: action.description,
      categoryId: action.categoryId,
      confidence: 1,
    );
    await _transactions.insertDraft(
      draft,
      accountId: action.accountId,
      idempotencyKey: 'chat:${Ids.newId()}',
      status: TxStatus.confirmed,
    );
    return 'Saved ${Money.display(action.amountMinor)}.';
  }

  Future<String> _confirmBudget(ProposedBudget action) async {
    await _categories.update(
      action.categoryId,
      budgetedAmountMinor: action.amountMinor,
    );
    return 'Budget saved.';
  }

  Future<ProposedTransaction> _resolveAddTransaction(
    String toolUseId,
    Map<String, dynamic> input,
  ) async {
    final categoryName = input['category_name'] as String?;
    final category = categoryName == null
        ? null
        : await _categories.byName(categoryName);
    final account = await _accounts.getDefault();

    return ProposedTransaction(
      toolUseId: toolUseId,
      amountMinor: Money.minorFromDouble((input['amount'] as num).toDouble()),
      direction: TxDirection.fromName(input['direction'] as String),
      accountId: account.id,
      merchant: input['merchant'] as String?,
      description: input['description'] as String?,
      categoryId: category?.id,
      categoryName: category?.displayName,
    );
  }

  /// Null means the category name didn't resolve — the caller turns
  /// that into an error tool_result rather than a broken proposal.
  Future<ProposedBudget?> _resolveSetBudget(
    String toolUseId,
    Map<String, dynamic> input,
  ) async {
    final category = await _categories.byName(input['category_name'] as String);
    if (category == null) return null;

    return ProposedBudget(
      toolUseId: toolUseId,
      categoryId: category.id,
      categoryName: category.displayName,
      amountMinor: Money.minorFromDouble((input['amount'] as num).toDouble()),
    );
  }

  Future<Map<String, dynamic>> _executeReadTool(
    String name,
    Map<String, dynamic> input,
  ) => switch (name) {
    'get_spending_summary' => _getSpendingSummary(input),
    'list_recent_transactions' => _listRecentTransactions(input),
    'get_budget_status' => _getBudgetStatus(input),
    _ => Future.value({'error': 'Unknown tool: $name'}),
  };

  Future<Map<String, dynamic>> _getSpendingSummary(
    Map<String, dynamic> input,
  ) async {
    final resolved = await _resolvePeriod(input['period'] as String?);
    final categoryFilter = (input['category_name'] as String?)?.toLowerCase();

    final breakdown = await _transactions
        .watchSpendByCategoryInRange(from: resolved.from, to: resolved.to)
        .first;
    final matching = categoryFilter == null
        ? breakdown
        : breakdown
              .where(
                (row) =>
                    row.categoryName.toLowerCase().contains(categoryFilter),
              )
              .toList();

    return {
      'period': resolved.label,
      'total_minor': matching.fold<int>(0, (sum, row) => sum + row.spentMinor),
      'breakdown': [
        for (final row in matching)
          {'category': row.categoryName, 'spent_minor': row.spentMinor},
      ],
    };
  }

  Future<Map<String, dynamic>> _listRecentTransactions(
    Map<String, dynamic> input,
  ) async {
    final limit = (input['limit'] as int?) ?? 10;
    final rows = await _transactions.watchRecent(limit: limit).first;
    final categories = {
      for (final category in await _categories.getAll()) category.id: category,
    };

    return {
      'transactions': [
        for (final row in rows)
          {
            'id': row.id,
            'date': row.transactedAt.toLocal().toIso8601String(),
            'merchant': stripPiiForLlm(row.merchant ?? ''),
            'amount_minor': row.amountMinor,
            'direction': row.direction.name,
            'category': row.categoryId == null
                ? null
                : categories[row.categoryId]?.displayName,
            'status': row.status.dbName,
          },
      ],
    };
  }

  Future<Map<String, dynamic>> _getBudgetStatus(
    Map<String, dynamic> input,
  ) async {
    final resolved = await _resolvePeriod(input['period'] as String?);
    final categories = await _categories.getAll();
    final periodAmounts = resolved.periodId == null
        ? const <String, int>{}
        : {
            for (final b in await _budgetPeriods.categoryBudgetsFor(
              resolved.periodId!,
            ))
              b.categoryId: b.amountMinor,
          };

    final budgeted = [
      for (final category in categories)
        if (category.isExpense)
          (
            category: category,
            limit: periodAmounts[category.id] ?? category.budgetedAmountMinor,
          ),
    ].where((row) => row.limit != null).toList();

    final spentByCategory = <String, int>{
      for (final row
          in await _transactions
              .watchSpendByCategoryInRange(
                from: resolved.from,
                to: resolved.to,
              )
              .first)
        if (row.categoryId != null) row.categoryId!: row.spentMinor,
    };

    return {
      'period': resolved.label,
      'budgets': [
        for (final row in budgeted)
          {
            'category': row.category.displayName,
            'limit_minor': row.limit,
            'spent_minor': spentByCategory[row.category.id] ?? 0,
          },
      ],
    };
  }

  /// Null → current budget period. `YYYY-MM` → that calendar month.
  /// Otherwise treat as a budget period id.
  Future<({String label, String from, String to, String? periodId})>
  _resolvePeriod(String? input) async {
    if (input == null || input.isEmpty) {
      final period = await _budgetPeriods.ensurePeriodContaining(
        DateTime.now(),
      );
      return (
        label: period.label,
        from: period.startAt,
        to: period.endAt,
        periodId: period.id,
      );
    }
    if (RegExp(r'^\d{4}-\d{2}$').hasMatch(input)) {
      final (from, to) = Iso.monthBoundsUtc(input);
      final parts = input.split('-');
      final year = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      return (
        label: Iso.periodLabel(
          DateTime(year, month),
          DateTime(year, month + 1),
        ),
        from: from,
        to: to,
        periodId: null,
      );
    }
    final period = await _budgetPeriods.getPeriod(input);
    if (period != null) {
      return (
        label: period.label,
        from: period.startAt,
        to: period.endAt,
        periodId: period.id,
      );
    }
    final fallback = await _budgetPeriods.ensurePeriodContaining(
      DateTime.now(),
    );
    return (
      label: fallback.label,
      from: fallback.startAt,
      to: fallback.endAt,
      periodId: fallback.id,
    );
  }

  Map<String, dynamic> _toolResultBlock(
    String toolUseId,
    Map<String, dynamic> content,
  ) {
    return {
      'type': 'tool_result',
      'tool_use_id': toolUseId,
      'content': jsonEncode(content),
    };
  }

  Map<String, dynamic> _toolResultsMessage(
    List<Map<String, dynamic>> blocks,
  ) {
    return {
      'role': 'user',
      'content': blocks,
    };
  }

  static const List<Map<String, dynamic>> _tools = [
    {
      'name': 'get_spending_summary',
      'description':
          'Confirmed debit spend for the current budget period (or a '
          'calendar month), broken down by category. Use for questions '
          'like "how much did I spend this period" or "how much on '
          'transport".',
      'strict': true,
      'input_schema': {
        'type': 'object',
        'properties': {
          'period': {
            'type': ['string', 'null'],
            'description':
                'Null means the current budget period. Pass YYYY-MM for a '
                'calendar month.',
          },
          'category_name': {
            'type': ['string', 'null'],
            'description':
                'Category to filter to, e.g. "Transport". Null means every '
                'category.',
          },
        },
        'required': ['period', 'category_name'],
        'additionalProperties': false,
      },
    },
    {
      'name': 'list_recent_transactions',
      'description':
          'Recent transactions with their id, date, merchant, amount, '
          'direction, category, and status. Use the id from here when the '
          'user refers to a specific past transaction.',
      'strict': true,
      'input_schema': {
        'type': 'object',
        'properties': {
          'limit': {
            'type': ['integer', 'null'],
            'description': 'Max rows to return. Null means 10.',
          },
        },
        'required': ['limit'],
        'additionalProperties': false,
      },
    },
    {
      'name': 'get_budget_status',
      'description':
          'Category budget limits vs confirmed spend for the current '
          'budget period (or a calendar month).',
      'strict': true,
      'input_schema': {
        'type': 'object',
        'properties': {
          'period': {
            'type': ['string', 'null'],
            'description':
                'Null means the current budget period. Pass YYYY-MM for a '
                'calendar month.',
          },
        },
        'required': ['period'],
        'additionalProperties': false,
      },
    },
    {
      'name': _proposeAddTransaction,
      'description':
          'Propose logging a transaction the user described. This shows a '
          'confirmation card and saves nothing by itself — call it as soon '
          'as the user describes a spend or a receipt, rather than asking '
          'first whether to log it.',
      'strict': true,
      'input_schema': {
        'type': 'object',
        'properties': {
          'amount': {
            'type': 'number',
            'description': 'Amount in major units, e.g. 50.0 for K50.',
          },
          'direction': {
            'type': 'string',
            'enum': ['debit', 'credit'],
          },
          'merchant': {
            'type': ['string', 'null'],
          },
          'description': {
            'type': ['string', 'null'],
          },
          'category_name': {
            'type': ['string', 'null'],
            'description': 'Best matching category name, or null if unclear.',
          },
        },
        'required': [
          'amount',
          'direction',
          'merchant',
          'description',
          'category_name',
        ],
        'additionalProperties': false,
      },
    },
    {
      'name': _proposeSetBudget,
      'description':
          'Propose a standing monthly budget limit for a category. This '
          'shows a confirmation card and saves nothing by itself.',
      'strict': true,
      'input_schema': {
        'type': 'object',
        'properties': {
          'category_name': {'type': 'string'},
          'amount': {
            'type': 'number',
            'description': 'Monthly limit in major units.',
          },
        },
        'required': ['category_name', 'amount'],
        'additionalProperties': false,
      },
    },
  ];
}
