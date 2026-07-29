/// The top-level destinations, in the order they appear in the
/// navigation bar.
///
/// This is the single source of truth for tab order: the home view
/// builds its destinations from [values], and deep links resolve to a
/// member by [slug]. Adding a section here adds it to both.
enum AppSection {
  activity,
  review,
  budgets,
  reports,
  chat,
  settings;

  /// The URL segment that addresses this section.
  String get slug => name;

  /// Position in the navigation bar.
  int get tabIndex => index;

  static AppSection? fromSlug(String slug) {
    for (final section in values) {
      if (section.slug == slug) return section;
    }
    return null;
  }

  static AppSection fromTabIndex(int index) =>
      index >= 0 && index < values.length ? values[index] : activity;
}
