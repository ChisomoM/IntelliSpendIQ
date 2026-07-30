import 'package:flutter_test/flutter_test.dart';
import 'package:intellispendiq/core/app_section.dart';
import 'package:intellispendiq/core/deep_link.dart';

void main() {
  DeepLink? parse(String uri) => DeepLink.parse(Uri.parse(uri));

  group('DeepLink.parse', () {
    test('resolves every section under the custom scheme', () {
      for (final section in AppSection.values) {
        expect(
          parse('intellispendiq://${section.slug}'),
          SectionLink(section),
          reason: '${section.slug} should address its own tab',
        );
      }
    });

    test('resolves the same sections as https app links', () {
      expect(
        parse('https://intellispendiq.app/budgets'),
        const SectionLink(AppSection.budgets),
      );
      expect(
        parse('https://intellispendiq.app/review/'),
        const SectionLink(AppSection.review),
        reason: 'A trailing slash is the same destination',
      );
    });

    test('resolves the capture actions', () {
      expect(parse('intellispendiq://add'), const AddTransactionLink());
      expect(parse('intellispendiq://voice'), const VoiceEntryLink());
      expect(
        parse('https://intellispendiq.app/voice'),
        const VoiceEntryLink(),
      );
    });

    test('resolves a single transaction by id', () {
      expect(
        parse('intellispendiq://transaction/abc-123'),
        const TransactionLink('abc-123'),
      );
      expect(
        parse('https://intellispendiq.app/transaction/abc-123'),
        const TransactionLink('abc-123'),
      );
    });

    test('returns null for anything unrecognised', () {
      for (final uri in [
        'intellispendiq://',
        'intellispendiq://nope',
        'intellispendiq://transaction',
        'intellispendiq://transaction/a/b',
        'https://intellispendiq.app/',
        'https://intellispendiq.app/nope',
      ]) {
        expect(
          parse(uri),
          isNull,
          reason: 'An unknown link must leave the user where they are: $uri',
        );
      }
    });

    test('ignores links belonging to another app or host', () {
      expect(parse('otherapp://review'), isNull);
      expect(
        parse('https://evil.example/review'),
        isNull,
        reason: 'Only the verified host may drive navigation',
      );
      expect(parse('https://intellispendiq.app.evil.example/review'), isNull);
    });
  });

  group('AppSection', () {
    test('slug round-trips', () {
      for (final section in AppSection.values) {
        expect(AppSection.fromSlug(section.slug), section);
      }
      expect(AppSection.fromSlug('nope'), isNull);
    });

    test('tab index round-trips for every nav-bar section', () {
      for (final section in AppSection.tabs) {
        expect(AppSection.fromTabIndex(section.tabIndex), section);
      }
    });

    test('a non-tab section has no tab index', () {
      for (final section in AppSection.values) {
        if (AppSection.tabs.contains(section)) continue;
        expect(section.isTab, isFalse);
        expect(section.tabIndex, -1);
      }
    });

    test('fromTabIndex clamps out-of-range values to Home', () {
      expect(AppSection.fromTabIndex(-1), AppSection.home);
      expect(AppSection.fromTabIndex(99), AppSection.home);
    });
  });
}
