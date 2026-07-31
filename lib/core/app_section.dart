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
  ///
  /// Tied to [name] deliberately: the slug is a compatibility surface —
  /// a link someone saved or a shortcut they made keeps working — so a
  /// member is never renamed just because its on-screen label changes.
  /// Display text lives in [label] instead.
  String get slug => name;

  /// What the section is called on screen.
  ///
  /// Plain words over product vocabulary: this is "Reports", not
  /// "Insights" or "Analytics", and "Assistant", not "AI".
  String get label => switch (this) {
    AppSection.home => 'Home',
    AppSection.activity => 'Activity',
    AppSection.budgets => 'Budgets',
    AppSection.reports => 'Reports',
    AppSection.review => 'Review',
    AppSection.chat => 'Assistant',
    AppSection.settings => 'Settings',
  };

  /// Bottom-nav destinations, in display order.
  ///
  /// Four, not more: the fifth slot is the capture FAB, and the
  /// sections not listed here are all *services* to these four rather
  /// than places you browse. Review trends to zero by design, the
  /// Assistant is invoked rather than visited, and Settings is rare —
  /// so all three live in the shell app bar and are reachable from
  /// every tab instead of occupying a permanent slot.
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
