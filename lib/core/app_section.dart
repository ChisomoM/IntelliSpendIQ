/// Every top-level destination the app can be deep-linked to.
///
/// Not every section is a bottom-nav tab — see [tabs]. Adding a member
/// here always extends the deep-link vocabulary (via [slug]); whether
/// it also gets a nav-bar slot is a separate decision made by [tabs].
enum AppSection {
  home,
  activity,
  budgets,
  reports,
  review,
  chat,
  settings;

  /// The URL segment that addresses this section.
  String get slug => name;

  /// Bottom-nav destinations, in display order. Sections not listed
  /// here (Review, Assistant, Settings) are reached by pushing a route
  /// on top of the current tab instead of switching tabs — see
  /// `HomeView._openLink`.
  static const List<AppSection> tabs = [home, activity, budgets, reports];

  bool get isTab => tabs.contains(this);

  /// Position in the navigation bar, or -1 if this section has no tab.
  int get tabIndex => tabs.indexOf(this);

  static AppSection? fromSlug(String slug) {
    for (final section in values) {
      if (section.slug == slug) return section;
    }
    return null;
  }

  static AppSection fromTabIndex(int index) =>
      index >= 0 && index < tabs.length ? tabs[index] : home;
}
