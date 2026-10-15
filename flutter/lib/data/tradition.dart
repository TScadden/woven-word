import 'bible_data.dart';
import 'deuterocanon.dart';
import 'scripture_text.dart';

/// The founder's tradition selection (board run 9): "you clicking
/// a toggle for what religion you are a part of and the app becomes
/// your religion." One persisted choice re-scopes the canon
/// presented, the connections corpus layered over verses, and
/// where reading links land. The woven Bible core stays underneath
/// every tradition, and [none] — Bible only — is a first-class
/// state, not an absence of one.
enum WwTradition {
  none('none', 'Bible only'),
  lds('lds', 'Latter-day Saint'),
  jewish('jewish', 'Jewish'),
  protestant('protestant', 'Protestant'),
  catholic('catholic', 'Catholic');

  const WwTradition(this.storedValue, this.label);

  /// The value persisted under [traditionPrefsKey].
  final String storedValue;

  /// The selection row's title in Profiles.
  final String label;

  static WwTradition fromStored(String? value) {
    for (final t in values) {
      if (t.storedValue == value) return t;
    }
    return WwTradition.none;
  }
}

/// The shared_preferences key for the tradition selection.
const String traditionPrefsKey = 'ww_tradition';

/// Translations the reader offers for a chapter of a core book
/// under [tradition]. The base pair (KJV, WEB) is always offered;
/// a tradition adds its own texts where they cover the book: JPS
/// 1917 and the Hebrew WLC cover the Tanakh (Old Testament) only,
/// and the WEB Catholic Edition covers the whole canon.
List<WwTranslation> translationsFor(
  WwTradition tradition, {
  required bool otBook,
}) {
  return switch (tradition) {
    WwTradition.jewish when otBook => const [
      WwTranslation.kjv,
      WwTranslation.web,
      WwTranslation.jps,
      WwTranslation.hebrew,
    ],
    WwTradition.catholic => const [
      WwTranslation.kjv,
      WwTranslation.web,
      WwTranslation.webc,
    ],
    _ => const [WwTranslation.kjv, WwTranslation.web],
  };
}

/// One book as a tradition presents it: the core book index plus
/// the display name (a tradition may name a book differently —
/// JPS prints "Song of Songs" where the core canon prints "Song of
/// Solomon"). Chapter addressing never changes: names are
/// presentation only, so verse keys stay canonical.
class CanonBookView {
  const CanonBookView(this.bookIndex, this.name);

  final int bookIndex;
  final String name;
}

/// A named run of books in a tradition's canon presentation
/// (Torah / Nevi'im / Ketuvim for the Tanakh; Old / New Testament
/// for the Christian canons).
class CanonSection {
  const CanonSection(this.title, this.books);

  final String title;
  final List<CanonBookView> books;
}

/// The canon as one tradition presents it: ordered sections of
/// core books. Every view covers its books exactly once; the
/// Jewish view covers the 39 Tanakh books only (the New Testament
/// is not part of that canon and is not presented).
class CanonView {
  const CanonView(this.sections);

  final List<CanonSection> sections;

  /// Every presented book index, in presentation order.
  List<int> get bookOrder => [
    for (final s in sections)
      for (final b in s.books) b.bookIndex,
  ];

  /// The display name of a presented book, or null when the view
  /// does not present it.
  String? nameFor(int bookIndex) {
    for (final s in sections) {
      for (final b in s.books) {
        if (b.bookIndex == bookIndex) return b.name;
      }
    }
    return null;
  }

  /// Tanakh presentation (Jewish tradition): Torah, Nevi'im,
  /// Ketuvim, in the JPS 1917 order. Book names stay the canon's
  /// own display names — the same names the reader, the search,
  /// and the verse keys use everywhere else in the app — so a
  /// book is never called two things in two places; what the
  /// tradition changes here is the ORDER and the grouping.
  static CanonView tanakh(BibleData data) {
    CanonBookView view(int i) => CanonBookView(i, data.books[i].name);
    return CanonView([
      CanonSection('Torah', [view(0), view(1), view(2), view(3), view(4)]),
      CanonSection("Nevi'im · Prophets", [
        view(5),
        view(6),
        view(8),
        view(9),
        view(10),
        view(11),
        view(22),
        view(23),
        view(25),
        view(27),
        view(28),
        view(29),
        view(30),
        view(31),
        view(32),
        view(33),
        view(34),
        view(35),
        view(36),
        view(37),
        view(38),
      ]),
      CanonSection('Ketuvim · Writings', [
        view(18),
        view(19),
        view(17),
        view(21),
        view(7),
        view(24),
        view(20),
        view(16),
        view(26),
        view(14),
        view(15),
        view(12),
        view(13),
      ]),
    ]);
  }

  /// The view for [tradition] over [data]'s canon. The Christian
  /// traditions share the shipped presentation (Old / New
  /// Testament in core order with core names); Catholic's extra
  /// books are presented by the deuterocanon surfaces, not here,
  /// because they are not core chapters.
  static CanonView forTradition(WwTradition tradition, BibleData data) {
    if (tradition == WwTradition.jewish) return tanakh(data);
    CanonBookView view(int i) => CanonBookView(i, data.books[i].name);
    final ot = [for (var i = 0; i < 39 && i < data.books.length; i++) view(i)];
    final nt = [for (var i = 39; i < data.books.length; i++) view(i)];
    return CanonView([
      CanonSection('Old Testament', ot),
      if (nt.isNotEmpty) CanonSection('New Testament', nt),
    ]);
  }
}

/// Canon dormancy (founder clarification, Oct 15, 2026): whether
/// [bookIndex] is in the canon [tradition] presents. This is a
/// VIEW predicate only — tradition is never a data scope. A
/// highlight or note whose book fails this predicate (or whose
/// translation set is not the active one) is dormant: stored
/// untouched, invisible, and restored exactly when the conditions
/// hold again. Core books defer to the tradition's [CanonView];
/// deuterocanon indices (≥ [DeuteroBook.bookIndexBase]) belong to
/// the Catholic canon only.
bool canonContainsBook(
  WwTradition tradition,
  BibleData data,
  int bookIndex,
) {
  if (bookIndex >= DeuteroBook.bookIndexBase) {
    return tradition == WwTradition.catholic;
  }
  return CanonView.forTradition(tradition, data).nameFor(bookIndex) != null;
}
