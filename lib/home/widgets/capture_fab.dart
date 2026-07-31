import 'package:flutter/material.dart';
import 'package:intellispendiq/transactions/transactions.dart';
import 'package:intellispendiq/voice/voice.dart';

/// The capture action, docked in the centre of the navigation bar.
///
/// Recording something is the most frequent *deliberate* action in the
/// app — SMS capture happens more often but needs no UI — so it gets the
/// one position reachable by thumb from any tab, instead of the previous
/// arrangement where the add button existed only on Activity and the
/// Dashboard had its own separate row of quick actions.
///
/// Tap types an entry; **hold speaks one**. The long-press is a
/// shortcut, never the only route: voice also has an explicit button on
/// Home and inside the entry screen itself, so nothing is hidden behind
/// a gesture the user has to discover.
class CaptureFab extends StatelessWidget {
  const CaptureFab({super.key});

  @override
  Widget build(BuildContext context) {
    // FloatingActionButton has no onLongPress of its own, so the gesture
    // is layered on outside it. The detector must not swallow the tap —
    // the FAB's own onPressed still handles that, and keeping them
    // separate is what preserves the ink splash and the tooltip.
    return GestureDetector(
      onLongPress: () => VoiceEntrySheet.show(context),
      child: FloatingActionButton(
        onPressed: () =>
            Navigator.of(context).push<void>(TransactionEntryPage.route()),
        tooltip: 'Add an entry. Hold to speak one.',
        child: const Icon(Icons.add, size: 28),
      ),
    );
  }
}
