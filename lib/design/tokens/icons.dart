import 'package:hugeicons/hugeicons.dart';
import 'package:intellispendiq/domain/models/category_icon_key.dart';

/// The app's icon vocabulary. Every icon used anywhere in the app is a
/// name from this file — nothing reaches for `Icons.*` or an emoji
/// directly, so the icon language stays one library end to end.
///
/// Values are `HugeIcons.strokeRounded*` constants; render them with
/// the shared `HugeIcon` widget (see `design/components/app_icon.dart`)
/// rather than calling the package type directly, so colour and size
/// stay themed.
abstract final class AppIcons {
  // Navigation.
  static const home = HugeIcons.strokeRoundedHome01;
  static const activity = HugeIcons.strokeRoundedTransactionHistory;
  static const budgets = HugeIcons.strokeRoundedWallet01;
  static const insights = HugeIcons.strokeRoundedPieChart;
  static const settings = HugeIcons.strokeRoundedSettings02;
  static const assistant = HugeIcons.strokeRoundedAiMagic;
  static const chat = HugeIcons.strokeRoundedAiChat02;
  static const review = HugeIcons.strokeRoundedNotification03;
  static const profile = HugeIcons.strokeRoundedUserCircle;

  // Primary actions.
  static const add = HugeIcons.strokeRoundedAdd01;
  static const voice = HugeIcons.strokeRoundedMic01;
  static const scanReceipt = HugeIcons.strokeRoundedScan;
  static const transfer = HugeIcons.strokeRoundedMoneyExchange01;

  // Direction (money in / out) — paired with words, never colour alone.
  static const moneyIn = HugeIcons.strokeRoundedMoneyReceive01;
  static const moneyOut = HugeIcons.strokeRoundedMoneySend01;

  // Chrome.
  static const chevronLeft = HugeIcons.strokeRoundedArrowLeft01;
  static const chevronRight = HugeIcons.strokeRoundedArrowRight01;
  static const close = HugeIcons.strokeRoundedCancel01;
  static const check = HugeIcons.strokeRoundedCheckmarkCircle01;
  static const search = HugeIcons.strokeRoundedSearch01;
  static const filter = HugeIcons.strokeRoundedFilterHorizontal;
  static const more = HugeIcons.strokeRoundedMoreVertical;
  static const edit = HugeIcons.strokeRoundedEdit02;
  static const delete = HugeIcons.strokeRoundedDelete02;
  static const calendar = HugeIcons.strokeRoundedCalendar03;
  static const undo = HugeIcons.strokeRoundedUndo02;
  static const eye = HugeIcons.strokeRoundedEye;
  static const bell = HugeIcons.strokeRoundedNotification03;

  // Security & privacy.
  static const lock = HugeIcons.strokeRoundedSquareLock01;
  static const fingerprint = HugeIcons.strokeRoundedFingerPrint;

  // Theme.
  static const sun = HugeIcons.strokeRoundedSun03;
  static const moon = HugeIcons.strokeRoundedMoon02;

  // Data & backup (Settings).
  static const exportData = HugeIcons.strokeRoundedFile02;
  static const backup = HugeIcons.strokeRoundedDatabaseExport;
  static const restore = HugeIcons.strokeRoundedDatabaseImport;
  static const bank = HugeIcons.strokeRoundedBank;
  static const senders = HugeIcons.strokeRoundedSmartPhone01;
  static const share = HugeIcons.strokeRoundedShare08;

  // Fallback for an unrecognised category icon key.
  static const unknown = HugeIcons.strokeRoundedHelpCircle;
}

/// Stable icon keys stored in `categories.icon`, resolved through
/// [CategoryIcons.byKey].
///
/// The seed data used to store emoji directly in that column. Emoji
/// are banned by the brand guide, so the seed and the picker now write
/// one of these keys instead, and [legacyEmojiToKey] maps the emoji a
/// user may already have on disk onto the equivalent key — a data
/// migration, not a find-and-replace, so nobody's customised category
/// loses its icon on upgrade.
abstract final class CategoryIcons {
  static const _registry = {
    CategoryIconKey.food: HugeIcons.strokeRoundedRestaurant01,
    CategoryIconKey.transport: HugeIcons.strokeRoundedBus01,
    CategoryIconKey.shopping: HugeIcons.strokeRoundedShoppingBag01,
    CategoryIconKey.bills: HugeIcons.strokeRoundedInvoice01,
    CategoryIconKey.income: HugeIcons.strokeRoundedMoneyBag01,
    CategoryIconKey.mobile: HugeIcons.strokeRoundedSmartPhone01,
    CategoryIconKey.bank: HugeIcons.strokeRoundedBank,
    CategoryIconKey.subscription: HugeIcons.strokeRoundedRepeat,
    CategoryIconKey.transfer: HugeIcons.strokeRoundedMoneyExchange01,
    CategoryIconKey.entertainment: HugeIcons.strokeRoundedMagicWand01,
    CategoryIconKey.other: AppIcons.unknown,
  };

  /// Maps the emoji this app used to seed `categories.icon` with onto
  /// the key that replaces it. Anything not listed here falls back to
  /// [CategoryIconKey.other] rather than failing to resolve.
  static const legacyEmojiToKey = {
    '🍲': CategoryIconKey.food,
    '🚌': CategoryIconKey.transport,
    '🛍': CategoryIconKey.shopping,
    '🛍️': CategoryIconKey.shopping,
    '🧾': CategoryIconKey.bills,
    '💰': CategoryIconKey.income,
    '📱': CategoryIconKey.mobile,
    '🏦': CategoryIconKey.bank,
    '📦': CategoryIconKey.other,
    '🔁': CategoryIconKey.transfer,
    '🎮': CategoryIconKey.entertainment,
    '❓': CategoryIconKey.other,
  };

  /// Resolves either a modern [CategoryIconKey] or a legacy emoji
  /// already stored on a device onto its icon — a value already on
  /// disk never needs a migration to keep rendering correctly.
  static List<List<dynamic>> byKey(String? icon) {
    final key = legacyEmojiToKey[icon] ?? icon;
    return _registry[key] ?? _registry[CategoryIconKey.other]!;
  }

  /// True when [icon] is a legacy emoji rather than a registry key —
  /// the signal a picker UI can use to know a value should be offered
  /// for remapping the next time the category is edited.
  static bool isLegacyEmoji(String? icon) =>
      icon != null && legacyEmojiToKey.containsKey(icon);
}
