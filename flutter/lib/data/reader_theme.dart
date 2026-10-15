/// The reader theme (reader theme package, founder ruling
/// Oct 15, 2026): the reader renders in one of two palettes —
/// Paper, the shipped cream page, or Dark, cream ink on the app's
/// black surface family. Dark is the default: [fromStored] maps
/// an absent or unrecognized stored value to Dark, so a fresh
/// install — and every existing install that has never stored a
/// choice — opens the reader in Dark. Paper is one switch away,
/// in Profiles or in the reader's own top bar.
///
/// The theme is a view concern only: it never scopes, moves, or
/// rewrites user data (the run-10 dormancy rule's cousin — spans,
/// notes, profiles, tradition, and translation are byte-identical
/// across a theme switch).
library;

const String readerThemePrefsKey = 'ww_reader_theme';

enum WwReaderTheme {
  paper('paper', 'Paper'),
  dark('dark', 'Dark');

  const WwReaderTheme(this.storedValue, this.label);

  final String storedValue;
  final String label;

  /// Dark-default parse: null, absent, or unrecognized → Dark.
  factory WwReaderTheme.fromStored(String? value) {
    for (final t in values) {
      if (t.storedValue == value) return t;
    }
    return WwReaderTheme.dark;
  }

  WwReaderTheme get other =>
      this == WwReaderTheme.dark ? WwReaderTheme.paper : WwReaderTheme.dark;
}
