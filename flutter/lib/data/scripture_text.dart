import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'bible_data.dart';

/// Top-level parse entry for [compute] in [ScriptureText.load].
ScriptureText _parsePair((String, String) args) =>
    ScriptureText.fromJsonStrings(args.$1, args.$2);

/// The two copyright-free translations bundled with the app.
enum WwTranslation {
  kjv('KJV', 'assets/kjv.json'),
  web('WEB', 'assets/web.json');

  const WwTranslation(this.label, this.assetPath);

  final String label;
  final String assetPath;

  static WwTranslation fromStored(String? value) =>
      value == web.label ? web : kjv;
}

/// Both scripture texts, parsed from assets/kjv.json and
/// assets/web.json. Each text is [bookIndex][chapterIndex0Based]
/// [verseIndex0Based] -> verse text, indexed through [BibleData]'s
/// chapters (b, c - 1, v - 1).
class ScriptureText {
  final List<List<List<String>>> _kjv;
  final List<List<List<String>>> _web;

  const ScriptureText._(this._kjv, this._web);

  /// Pure parse of the two asset payloads (testable without the
  /// asset bundle).
  static ScriptureText fromJsonStrings(String kjv, String web) =>
      ScriptureText._(_parse(kjv), _parse(web));

  static List<List<List<String>>> _parse(String source) {
    final json = jsonDecode(source) as List;
    return [
      for (final book in json)
        [
          for (final chapter in book as List)
            [for (final verse in chapter as List) verse as String],
        ],
    ];
  }

  /// Loads both texts off the UI thread.
  static Future<ScriptureText> load() async {
    final kjv = await rootBundle.loadString(WwTranslation.kjv.assetPath);
    final web = await rootBundle.loadString(WwTranslation.web.assetPath);
    return compute(_parsePair, (kjv, web));
  }

  List<List<List<String>>> _text(WwTranslation t) =>
      t == WwTranslation.kjv ? _kjv : _web;

  /// Every verse of a chapter in one translation, in order. An
  /// out-of-range chapter returns an empty list, never a throw.
  List<String> chapterVerses(WwTranslation t, BibleData data, int ch) {
    if (ch < 0 || ch >= data.chapters.length) return const [];
    final chapter = data.chapters[ch];
    final books = _text(t);
    if (chapter.b < 0 || chapter.b >= books.length) return const [];
    final chapters = books[chapter.b];
    final idx = chapter.c - 1;
    if (idx < 0 || idx >= chapters.length) return const [];
    return chapters[idx];
  }

  /// One verse's text in one translation. The verse clamps to THIS
  /// translation's own chapter length — the versifications differ
  /// (e.g. Romans 14 and 16 in WEB vs KJV), so a verse numbered from
  /// the data index can run past a shorter text chapter. An
  /// out-of-range chapter or an empty text chapter returns ''.
  String verseText(WwTranslation t, BibleData data, int ch, int v) {
    final verses = chapterVerses(t, data, ch);
    if (verses.isEmpty) return '';
    return verses[v.clamp(1, verses.length) - 1];
  }
}
