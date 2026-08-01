import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intellispendiq/data/repositories/raw_capture_repository.dart';
import 'package:intellispendiq/design/design.dart';
import 'package:intellispendiq/domain/models/raw_capture.dart';
import 'package:intl/intl.dart';

/// The original message an entry was read from, verbatim.
///
/// The brand guide requires the raw source of a parsed entry always be
/// retrievable — "name the source when we guess, and offer the raw
/// text". Before this the text was captured and stored but had no way
/// to reach the UI once parsing had succeeded, so a user could not
/// check the app's reading against what their bank actually sent.
class RawSourceSheet extends StatelessWidget {
  const RawSourceSheet({required this.rawCaptureId, super.key});

  final String rawCaptureId;

  static Future<void> show(
    BuildContext context, {
    required String rawCaptureId,
  }) {
    final rawCaptures = context.read<RawCaptureRepository>();
    return AppSheet.show<void>(
      context,
      builder: (_) => RepositoryProvider.value(
        value: rawCaptures,
        child: RawSourceSheet(rawCaptureId: rawCaptureId),
      ),
    );
  }

  static final _receivedFormat = DateFormat('d MMM yyyy, HH:mm');

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return FutureBuilder<RawCapture?>(
      future: context.read<RawCaptureRepository>().byId(rawCaptureId),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: Space.x4),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final capture = snapshot.data;
        if (capture == null) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: Space.x2),
            child: ErrorState(
              message: 'The original message is no longer on this phone.',
            ),
          );
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Original message', style: AppTypography.sectionHeader()),
            const SizedBox(height: 4),
            Text(
              [
                if (capture.sender != null) 'From ${capture.sender}',
                _receivedFormat.format(capture.receivedAt.toLocal()),
              ].join(' · '),
              style: AppTypography.metadata(color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: Space.x2),
            AppCard(
              child: SelectableText(
                capture.body,
                style: AppTypography.body(color: colors.onSurface),
              ),
            ),
            const SizedBox(height: Space.x2),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await Clipboard.setData(
                        ClipboardData(text: capture.body),
                      );
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Copied.')),
                      );
                    },
                    icon: AppIcon(AppIcons.exportData, size: 18),
                    label: const Text('Copy'),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}
