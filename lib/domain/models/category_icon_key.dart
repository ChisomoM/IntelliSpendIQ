/// Stable string keys stored in `categories.icon`.
///
/// This lives in the domain layer, not the design system, so the data
/// layer can seed categories with a real icon reference without
/// importing UI code. `design/tokens/icons.dart` maps each of these
/// keys onto an actual glyph; this file only owns the vocabulary.
///
/// The seed data used to store an emoji directly in this column —
/// banned by the brand guide. `CategoryIcons.byKey` (design layer)
/// still resolves an emoji already on a device onto the matching key
/// below, so nobody's customised category loses its icon on upgrade;
/// nothing here needs to migrate stored rows.
abstract final class CategoryIconKey {
  static const food = 'food';
  static const transport = 'transport';
  static const shopping = 'shopping';
  static const bills = 'bills';
  static const income = 'income';
  static const mobile = 'mobile';
  static const bank = 'bank';
  static const subscription = 'subscription';
  static const transfer = 'transfer';
  static const entertainment = 'entertainment';
  static const other = 'other';
}
