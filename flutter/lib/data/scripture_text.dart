import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'bible_data.dart';

/// The copyright-free translations bundled with the app. KJV and
/// WEB are the base pair (board run 3); board run 9 adds the
/// tradition texts: JPS 1917 and the Hebrew WLC for the Tanakh,
/// and the WEB Catholic Edition for the 73-book canon. Every one
/// is public domain (see the pipelines' LICENSE-EVIDENCE files).
enum WwTranslation {
  kjv('KJV', 'assets/kjv.json'),
  web('WEB', 'assets/web.json'),
  jps('JPS', 'assets/jps.json'),
  hebrew('Hebrew', 'assets/hebrew.json'),
  webc('WEBC', 'assets/webc.json');

  const WwTranslation(this.label, this.assetPath);

  final String label;
  final String assetPath;

  /// The compact form the reader's toggle shows: four glyphs at
  /// most, so a three-option toggle fits the top bar beside the
  /// longest book titles at phone widths (board run 9 — 'WEB
  /// Catholic' and 'Hebrew' as full labels overflowed it).
  String get toggleLabel => switch (this) {
    WwTranslation.kjv => 'KJV',
    WwTranslation.web => 'WEB',
    WwTranslation.jps => 'JPS',
    WwTranslation.hebrew => 'HEB',
    WwTranslation.webc => 'WEBC',
  };

  /// Right-to-left text (the Hebrew WLC): verse blocks and sheet
  /// snippets render RTL when this is the effective translation.
  bool get isRtl => this == WwTranslation.hebrew;

  static WwTranslation fromStored(String? value) {
    for (final t in values) {
      if (t.label == value) return t;
    }
    return WwTranslation.kjv;
  }
}

/// All bundled scripture texts. Each text is stored in ITS OWN
/// book order as [book][chapter][verse] -> verse text, with a
/// per-translation map from its own book index to the core
/// canon's book index (-1 for a deuterocanon book, which instead
/// carries an extra slug). Core chapters resolve through
/// [BibleData]'s chapter table (b, c - 1, v - 1) exactly as
/// before; deuterocanon chapters resolve through
/// [extraChapterVerses].
class ScriptureText {
  ScriptureText._(this._texts, this._coreOfBook, this._extraOfBook);

  final Map<WwTranslation, List<List<List<String>>>> _texts;

  /// Per translation: own book index -> core book index, or -1
  /// for a deuterocanon (extra) book.
  final Map<WwTranslation, List<int>> _coreOfBook;

  /// Per translation: own book index -> extra slug, or '' for a
  /// core book.
  final Map<WwTranslation, List<String>> _extraOfBook;

  static List<List<List<String>>> _parseText(String source) {
    final json = jsonDecode(source) as List;
    return [
      for (final book in json)
        [
          for (final chapter in book as List)
            [for (final verse in chapter as List) verse as String],
        ],
    ];
  }

  static List<int> _identityCore(int books) => [
    for (var i = 0; i < books; i++) i,
  ];

  static List<String> _noExtras(int books) => [
    for (var i = 0; i < books; i++) '',
  ];

  /// Pure parse of the two base payloads (testable without the
  /// asset bundle) — the shipped seam every existing test uses.
  static ScriptureText fromJsonStrings(String kjv, String web) {
    final kjvText = _parseText(kjv);
    final webText = _parseText(web);
    return ScriptureText._(
      {WwTranslation.kjv: kjvText, WwTranslation.web: webText},
      {
        WwTranslation.kjv: _identityCore(kjvText.length),
        WwTranslation.web: _identityCore(webText.length),
      },
      {
        WwTranslation.kjv: _noExtras(kjvText.length),
        WwTranslation.web: _noExtras(webText.length),
      },
    );
  }

  /// Full parse for [load]: the base pair plus whichever
  /// tradition payloads were bundled. JPS and Hebrew assets are
  /// built in core book order (NT slots empty), so their book map
  /// is the identity; the WEBC asset is in its own order and its
  /// book map comes from the bundled `webc_books.json`
  /// ([{"core":0|null,"extra":"tobit"|null}, …]).
  static ScriptureText fromPayloads({
    required String kjv,
    required String web,
    String? jps,
    String? hebrew,
    String? webc,
    String? webcBooks,
  }) {
    final texts = <WwTranslation, List<List<List<String>>>>{};
    final coreOf = <WwTranslation, List<int>>{};
    final extraOf = <WwTranslation, List<String>>{};
    void addCoreOrdered(WwTranslation t, String source) {
      final parsed = _parseText(source);
      texts[t] = parsed;
      coreOf[t] = _identityCore(parsed.length);
      extraOf[t] = _noExtras(parsed.length);
    }

    addCoreOrdered(WwTranslation.kjv, kjv);
    addCoreOrdered(WwTranslation.web, web);
    if (jps != null) addCoreOrdered(WwTranslation.jps, jps);
    if (hebrew != null) addCoreOrdered(WwTranslation.hebrew, hebrew);
    if (webc != null && webcBooks != null) {
      final parsed = _parseText(webc);
      final mapJson = jsonDecode(webcBooks) as List;
      final core = <int>[];
      final extra = <String>[];
      for (var i = 0; i < parsed.length; i++) {
        final entry = i < mapJson.length ? mapJson[i] as Map : const {};
        final coreRaw = entry['core'];
        final extraRaw = entry['extra'];
        core.add(coreRaw is num ? coreRaw.toInt() : -1);
        extra.add(extraRaw is String ? extraRaw : '');
      }
      texts[WwTranslation.webc] = parsed;
      coreOf[WwTranslation.webc] = core;
      extraOf[WwTranslation.webc] = extra;
    }
    return ScriptureText._(texts, coreOf, extraOf);
  }

  /// Loads the bundled texts off the UI thread. The base pair is
  /// required; each tradition asset is best-effort — an absent
  /// asset leaves that translation unavailable and the reader
  /// falls back (failures-as-values, like the layer loaders).
  static Future<ScriptureText> load() async {
    final kjv = await rootBundle.loadString(WwTranslation.kjv.assetPath);
    final web = await rootBundle.loadString(WwTranslation.web.assetPath);
    Future<String?> optional(String path) async {
      try {
        return await rootBundle.loadString(path);
      } catch (_) {
        return null;
      }
    }

    final jps = await optional(WwTranslation.jps.assetPath);
    final hebrew = await optional(WwTranslation.hebrew.assetPath);
    final webc = await optional(WwTranslation.webc.assetPath);
    final webcBooks = await optional('assets/webc_books.json');
    return compute(_parseAll, (kjv, web, jps, hebrew, webc, webcBooks));
  }

  /// Whether [t]'s text is bundled in this instance.
  bool hasTranslation(WwTranslation t) => _texts.containsKey(t);

  /// Every verse of a core chapter in one translation, in order.
  /// A translation that does not cover the chapter (JPS or Hebrew
  /// on a New Testament chapter) falls back to the KJV's chapter —
  /// a held place never renders blank. An out-of-range chapter
  /// returns an empty list, never a throw.
  List<String> chapterVerses(WwTranslation t, BibleData data, int ch) {
    final verses = _chapterVersesOrNull(t, data, ch);
    if (verses != null && verses.isNotEmpty) return verses;
    if (t != WwTranslation.kjv) {
      return _chapterVersesOrNull(WwTranslation.kjv, data, ch) ?? const [];
    }
    return const [];
  }

  List<String>? _chapterVersesOrNull(WwTranslation t, BibleData data, int ch) {
    if (ch < 0 || ch >= data.chapters.length) return null;
    final books = _texts[t];
    final coreOf = _coreOfBook[t];
    if (books == null || coreOf == null) return null;
    final chapter = data.chapters[ch];
    final own = coreOf.indexOf(chapter.b);
    if (own < 0 || own >= books.length) return null;
    final chapters = books[own];
    final idx = chapter.c - 1;
    if (idx < 0 || idx >= chapters.length) return null;
    return chapters[idx];
  }

  /// One verse's text in one translation. The verse clamps to
  /// THIS translation's own chapter length — the versifications
  /// differ (e.g. Romans 14 and 16 in WEB vs KJV), so a verse
  /// numbered from the data index can run past a shorter text
  /// chapter. An out-of-range chapter or an empty text chapter
  /// returns ''.
  String verseText(WwTranslation t, BibleData data, int ch, int v) {
    final verses = chapterVerses(t, data, ch);
    if (verses.isEmpty) return '';
    return verses[v.clamp(1, verses.length) - 1];
  }

  /// Every verse of a deuterocanon chapter in the WEB Catholic
  /// Edition, in order. [slug] is the book's deuterocanon slug
  /// and [chapterInBook] is 1-based. Unknown slugs and chapters
  /// return an empty list.
  List<String> extraChapterVerses(String slug, int chapterInBook) {
    final books = _texts[WwTranslation.webc];
    final extraOf = _extraOfBook[WwTranslation.webc];
    if (books == null || extraOf == null) return const [];
    final own = extraOf.indexOf(slug);
    if (own < 0 || own >= books.length) return const [];
    final chapters = books[own];
    final idx = chapterInBook - 1;
    if (idx < 0 || idx >= chapters.length) return const [];
    return chapters[idx];
  }

  /// One deuterocanon verse's text, clamped to the chapter's own
  /// length; '' when the chapter has no text.
  String extraVerseText(String slug, int chapterInBook, int verse) {
    final verses = extraChapterVerses(slug, chapterInBook);
    if (verses.isEmpty) return '';
    return verses[verse.clamp(1, verses.length) - 1];
  }
}

/// Top-level parse entry for [compute] in [ScriptureText.load].
ScriptureText _parseAll(
  (String, String, String?, String?, String?, String?) args,
) => ScriptureText.fromPayloads(
  kjv: args.$1,
  web: args.$2,
  jps: args.$3,
  hebrew: args.$4,
  webc: args.$5,
  webcBooks: args.$6,
);
