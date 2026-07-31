import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intellispendiq/data/repositories/raw_capture_repository.dart';
import 'package:intellispendiq/data/repositories/transaction_repository.dart';
import 'package:intellispendiq/data/repositories/transfer_repository.dart';
import 'package:intellispendiq/review/cubit/cubit.dart';
import 'package:intellispendiq/review/widgets/widgets.dart';

/// The Review Inbox: every capture that needs a human glance, in one
/// place (plan §10.1). Nothing is ever silently dropped — failed parses,
/// low-confidence voice entries, and duplicate suspects all land here.
class ReviewInboxPage extends StatelessWidget {
  const ReviewInboxPage({super.key});

  static Route<void> route() {
    return MaterialPageRoute<void>(builder: (_) => const ReviewInboxPage());
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ReviewInboxCubit(
        transactions: context.read<TransactionRepository>(),
        rawCaptures: context.read<RawCaptureRepository>(),
        transfers: context.read<TransferRepository>(),
      )..subscribe(),
      child: const ReviewInboxView(),
    );
  }
}

class ReviewInboxView extends StatelessWidget {
  const ReviewInboxView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Review')),
      body: BlocBuilder<ReviewInboxCubit, ReviewInboxState>(
        builder: (context, state) {
          if (state.isEmpty) return const InboxZero();

          return ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              if (state.transferCandidates.isNotEmpty) ...[
                const SectionHeader(
                  title: 'Possible transfers',
                  subtitle:
                      'A debit and a credit of the same amount on two of '
                      'your accounts, close together in time.',
                ),
                for (final candidate in state.transferCandidates)
                  TransferCandidateTile(candidate: candidate),
              ],
              if (state.duplicates.isNotEmpty) ...[
                const SectionHeader(
                  title: 'Possible duplicates',
                  subtitle:
                      'Same amount and merchant within 30 minutes of an '
                      'existing entry. Keep both if they are real.',
                ),
                for (final transaction in state.duplicates)
                  DuplicateTile(transaction: transaction),
              ],
              if (state.needsReview.isNotEmpty) ...[
                const SectionHeader(
                  title: 'Needs a detail',
                  subtitle:
                      'Captured, but missing a category or below the '
                      'confidence bar for auto-saving.',
                ),
                for (final transaction in state.needsReview)
                  NeedsReviewTile(transaction: transaction),
              ],
              if (state.failedCaptures.isNotEmpty) ...[
                const SectionHeader(
                  title: 'Could not read',
                  subtitle:
                      'Messages from a known sender that no parser '
                      'understood. The original text is kept.',
                ),
                for (final capture in state.failedCaptures)
                  FailedCaptureTile(capture: capture),
              ],
            ],
          );
        },
      ),
    );
  }
}
