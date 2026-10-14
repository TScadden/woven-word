import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/bible_data.dart';
import '../data/conference_data.dart';
import '../data/scripture_text.dart';
import '../theme/ww_theme.dart';
import 'library_tab.dart';
import 'reader_screen.dart';

/// The General Conference browse branch (board run 8, spec §4):
/// Library root → conferences list → talks list → talk view,
/// inside the Library tab's existing navigator. Every level is
/// built from the shipped sub-screen patterns — `libraryTopBar`,
/// the profile/My Notes list rows, the gold primary action — and
/// hosts citation FACTS only: talk title, speaker, conference,
/// and the Bible references it cites. Talk text is never hosted;
/// the one way out is the talk view's Gospel Library action.

/// Attribution (spec §5, copy C-22): plain text, in exactly two
/// placements — the conferences list footer and the talk view
/// footer. Never a control, never a link.
const wwConferenceAttribution =
    'Citation facts are from the Scripture Citation Index '
    '(scriptures.byu.edu), compiled by Richard C. Galbraith and '
    'Stephen W. Liddle.';

/// The non-Bible-citations caption (spec §4.4.3, copy C-21),
/// mandatory on every talk view.
const wwNonBibleCitationsCaption =
    'This list shows Bible citations only. The talk may also cite '
    'the Book of Mormon, Doctrine and Covenants, Pearl of Great '
    'Price, and other sources, which this Bible app does not list.';

/// '{Month} {Year}' for a conference (year, session) pair — the
/// same label [ConferenceTalk.conferenceLabel] gives a talk.
String conferenceMonthYear(int year, String session) =>
    '${session == 'O' ? 'October' : 'April'} $year';

/// The shipped counted pattern: '1 talk' / '3 talks'.
String counted(int n, String singular, String plural) =>
    '$n ${n == 1 ? singular : plural}';

/// The number of distinct Bible verses [talkId]'s talk view will
/// list (§4.3's K): the summed verses of its canon-ordered
/// reference groups.
int talkScriptureCount(ConferenceData data, int talkId) {
  var k = 0;
  for (final group in data.refsForTalk(talkId)) {
    k += group.$3.length;
  }
  return k;
}

/// The talks of one conference the browse lists (§4.3 inclusion
/// rule): dataset session order (§3.3 tie-break), keeping only
/// talks with at least one Bible citation. [ConferenceData]
/// .talksInConference preserves dataset order; the citation
/// filter is applied here, at the surface the rule governs.
List<ConferenceTalk> citingTalks(
  ConferenceData data,
  int year,
  String session,
) => [
  for (final talk in data.talksInConference(year, session))
    if (data.refsForTalk(talk.id).isNotEmpty) talk,
];

/// One browse list row (spec §4.2/§4.3): the shipped list-row
/// construction — Material(surface, row radius) + InkWell,
/// minHeight 48, horizontal 12 / vertical 8 padding, the whole
/// row the tap target, a disclosure chevron trailing. The row is
/// one semantics node (container, button) with the caller's
/// §7 label.
Widget browseRow({
  required String title,
  required String subtitle,
  required String semanticsLabel,
  required VoidCallback onTap,
}) {
  return Semantics(
    container: true,
    button: true,
    label: semanticsLabel,
    child: Material(
      color: WwColors.surface,
      borderRadius: BorderRadius.circular(WwRadius.row),
      child: InkWell(
        borderRadius: BorderRadius.circular(WwRadius.row),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: WwSpace.minTarget),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: WwType.controlLabel.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(subtitle, style: WwType.captionOnDark),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                size: 20,
                color: WwColors.mutedOnDark,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// The conferences list (spec §4.2): newest first, one row per
/// conference that has at least one listed talk — exactly the
/// inclusion [ConferenceData.conferences] already applies — with
/// the intro caption that scopes every count below it and the
/// attribution footer (§5 placement 2).
class ConferenceListScreen extends StatelessWidget {
  const ConferenceListScreen({
    super.key,
    required this.conferenceData,
    required this.onBack,
    required this.onBreadcrumbRoot,
    required this.onOpenConference,
  });

  final ConferenceData conferenceData;
  final VoidCallback onBack;
  final VoidCallback onBreadcrumbRoot;
  final void Function(int year, String session) onOpenConference;

  @override
  Widget build(BuildContext context) {
    final conferences = conferenceData.conferences();
    return Scaffold(
      backgroundColor: WwColors.stage,
      body: SafeArea(
        child: Column(
          children: [
            libraryTopBar(
              title: 'General Conference',
              onBack: onBack,
              breadcrumbItems: const [
                ('library', 'Library'),
                ('__current', 'General Conference'),
              ],
              onBreadcrumb: (value) {
                if (value == 'library') onBreadcrumbRoot();
              },
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(WwSpace.screenMargin),
                children: [
                  const Text(
                    'Newest first. Talk counts include only talks that '
                    'cite the Bible.',
                    style: WwType.captionOnDark,
                  ),
                  const SizedBox(height: 16),
                  for (var i = 0; i < conferences.length; i++) ...[
                    if (i > 0) const SizedBox(height: 8),
                    _row(conferences[i]),
                  ],
                  const SizedBox(height: 16),
                  const Text(
                    wwConferenceAttribution,
                    style: WwType.captionOnDark,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row((int, String, int) conference) {
    final (year, session, count) = conference;
    final label = conferenceMonthYear(year, session);
    final talks = counted(count, 'talk', 'talks');
    return browseRow(
      title: label,
      subtitle: talks,
      semanticsLabel: 'Open $label conference, $talks',
      onTap: () => onOpenConference(year, session),
    );
  }
}

/// One conference's talks list (spec §4.3): dataset session
/// order, citing talks only, each subtitle counting the distinct
/// Bible verses its talk view will list.
class ConferenceTalksScreen extends StatelessWidget {
  const ConferenceTalksScreen({
    super.key,
    required this.conferenceData,
    required this.year,
    required this.session,
    required this.onBack,
    required this.onBreadcrumb,
    required this.onOpenTalk,
  });

  final ConferenceData conferenceData;
  final int year;
  final String session;
  final VoidCallback onBack;

  /// Breadcrumb selections: 'library' or 'conferences'.
  final void Function(String value) onBreadcrumb;
  final void Function(ConferenceTalk talk) onOpenTalk;

  @override
  Widget build(BuildContext context) {
    final label = conferenceMonthYear(year, session);
    final talks = citingTalks(conferenceData, year, session);
    return Scaffold(
      backgroundColor: WwColors.stage,
      body: SafeArea(
        child: Column(
          children: [
            libraryTopBar(
              title: label,
              onBack: onBack,
              breadcrumbItems: [
                ('library', 'Library'),
                ('conferences', 'General Conference'),
                ('__current', label),
              ],
              onBreadcrumb: onBreadcrumb,
            ),
            Expanded(
              child: talks.isEmpty
                  ? const Center(
                      child: Text(
                        'No talks are listed for this conference.',
                        style: WwType.captionOnDark,
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.all(WwSpace.screenMargin),
                      children: [
                        for (var i = 0; i < talks.length; i++) ...[
                          if (i > 0) const SizedBox(height: 8),
                          _row(talks[i]),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(ConferenceTalk talk) {
    final k = talkScriptureCount(conferenceData, talk.id);
    return browseRow(
      title: talk.title,
      subtitle: '${talk.speaker} · ${counted(k, 'scripture', 'scriptures')}',
      semanticsLabel: 'Open talk: ${talk.title}, by ${talk.speaker}',
      onTap: () => onOpenTalk(talk),
    );
  }
}

/// The talk view (spec §4.4): facts about one talk and the Bible
/// verses it cites, in the spec's exact body order, with the
/// Gospel Library action (§4.4.1) above the scripture list.
class TalkViewScreen extends StatefulWidget {
  const TalkViewScreen({
    super.key,
    required this.data,
    required this.conferenceData,
    required this.talk,
    required this.onBack,
    required this.onBreadcrumb,
    required this.onOpenVerse,
    this.textsLoader,
    this.externalLauncher,
  });

  final BibleData data;
  final ConferenceData conferenceData;
  final ConferenceTalk talk;
  final VoidCallback onBack;

  /// Breadcrumb selections: 'library', 'conferences', or 'talks'.
  final void Function(String value) onBreadcrumb;

  /// Opens a cited verse through the shell's one open-chapter
  /// procedure (§4.4.2): (globalChapter, verse).
  final void Function(int globalChapter, int? verse) onOpenVerse;

  /// Loads both scripture texts; defaults to [ScriptureText.load].
  /// Tests inject a fake through this seam, as the reader does.
  final Future<ScriptureText> Function()? textsLoader;

  /// Opens an external URL; defaults to url_launcher in external
  /// application mode. Tests inject a fake through this seam.
  /// Returns whether the open was accepted.
  final Future<bool> Function(Uri uri)? externalLauncher;

  @override
  State<TalkViewScreen> createState() => _TalkViewScreenState();
}

class _TalkViewScreenState extends State<TalkViewScreen> {
  ScriptureText? _texts;
  WwTranslation _translation = WwTranslation.kjv;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Snippets follow the active translation (§1.1), loaded the
  /// My Notes way: the stored translation preference, then both
  /// texts. A failed text load leaves the rows' references
  /// standing with empty snippets rather than failing the view.
  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _translation = WwTranslation.fromStored(
        prefs.getString(ReaderScreen.translationKey),
      );
    } catch (_) {
      // The default translation stands.
    }
    try {
      final texts = await (widget.textsLoader ?? ScriptureText.load)();
      if (mounted) setState(() => _texts = texts);
    } catch (_) {
      // Snippets are best-effort, as in My Notes.
    }
  }

  Future<bool> _defaultLaunch(Uri uri) =>
      launchUrl(uri, mode: LaunchMode.externalApplication);

  /// The Gospel Library action (§4.4.1): a failed open is never
  /// silent — it lands in the run-6 snackbar construction with
  /// copy C-20.
  Future<void> _openInGospelLibrary() async {
    final url = widget.talk.url;
    if (url == null) return;
    var ok = false;
    try {
      ok = await (widget.externalLauncher ?? _defaultLaunch)(
        Uri.parse(url),
      );
    } catch (_) {
      ok = false;
    }
    if (ok || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: WwColors.surfaceHigh,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(WwRadius.chip),
        ),
        content: const Text(
          'Could not open Gospel Library.',
          style: WwType.bodyOnDark,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final talk = widget.talk;
    return Scaffold(
      backgroundColor: WwColors.stage,
      body: SafeArea(
        child: Column(
          children: [
            libraryTopBar(
              title: talk.conferenceLabel,
              onBack: widget.onBack,
              breadcrumbItems: [
                ('library', 'Library'),
                ('conferences', 'General Conference'),
                ('talks', talk.conferenceLabel),
                ('__current', talk.title),
              ],
              onBreadcrumb: widget.onBreadcrumb,
            ),
            Expanded(child: _body()),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    final talk = widget.talk;
    final groups = widget.conferenceData.refsForTalk(talk.id);
    final rows = <Widget>[];
    for (final (bookIndex, chapterInBook, verses) in groups) {
      final global = widget.data.books[bookIndex].start + chapterInBook - 1;
      for (final verse in verses) {
        if (rows.isNotEmpty) rows.add(const SizedBox(height: 8));
        rows.add(_scriptureRow(global, verse));
      }
    }
    return ListView(
      padding: const EdgeInsets.all(WwSpace.screenMargin),
      children: [
        Text(talk.title, style: WwType.selectionTitle),
        const SizedBox(height: 4),
        Text(talk.speaker, style: WwType.bodyOnDark),
        const SizedBox(height: 2),
        Text(
          '${talk.conferenceLabel} General Conference',
          style: WwType.captionOnDark,
        ),
        const SizedBox(height: 16),
        ..._gospelAction(),
        const SizedBox(height: 24),
        const Text('Scriptures cited', style: WwType.refLabelOnDark),
        const SizedBox(height: 8),
        if (rows.isEmpty)
          const Text(
            'No Bible verses are listed for this talk.',
            style: WwType.captionOnDark,
          )
        else
          ...rows,
        const SizedBox(height: 16),
        const Text(wwNonBibleCitationsCaption, style: WwType.captionOnDark),
        const SizedBox(height: 8),
        const Text(wwConferenceAttribution, style: WwType.captionOnDark),
      ],
    );
  }

  /// The Gospel Library action in its three ruled forms
  /// (§4.4.1): Form A (per-talk link), Form B (conference-level
  /// fallback, with its mandatory caption), and the no-link
  /// caption in the button's place. No disabled form exists.
  List<Widget> _gospelAction() {
    final talk = widget.talk;
    final url = talk.url;
    if (url == null) {
      return const [
        Text(
          'This talk is not linked in Gospel Library.',
          style: WwType.captionOnDark,
        ),
      ];
    }
    if (talk.urlIsConference) {
      return [
        _gospelButton(
          label: 'Open this conference in Gospel Library',
          semanticsLabel:
              'Open the ${talk.conferenceLabel} conference in Gospel '
              'Library, opens external app or website',
        ),
        const SizedBox(height: 8),
        const Text(
          'This talk has no direct link, so this opens its '
          'conference in Gospel Library.',
          style: WwType.captionOnDark,
        ),
      ];
    }
    return [
      _gospelButton(
        label: 'Read in Gospel Library',
        semanticsLabel:
            'Read ${talk.title} in Gospel Library, opens external '
            'app or website',
      ),
    ];
  }

  Widget _gospelButton({
    required String label,
    required String semanticsLabel,
  }) {
    return Semantics(
      container: true,
      button: true,
      label: semanticsLabel,
      child: ElevatedButton(
        onPressed: _openInGospelLibrary,
        style: ElevatedButton.styleFrom(
          backgroundColor: WwColors.goldBright,
          foregroundColor: WwColors.onGold,
          minimumSize: const Size.fromHeight(WwSpace.minTarget),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(WwRadius.chip),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.open_in_new,
              size: 18,
              color: WwColors.onGold,
            ),
            const SizedBox(width: 8),
            Text(label, style: WwType.goldButtonLabel),
          ],
        ),
      ),
    );
  }

  /// One distinct cited verse (§4.4.2): the My Notes row
  /// construction on dark — reference in refLabelOnDark, the
  /// verse's own text in bodyOnDark in the active translation
  /// (the paper role `snippet` is prohibited on this surface),
  /// capped at 3 lines, disclosure chevron trailing.
  Widget _scriptureRow(int globalChapter, int verse) {
    final data = widget.data;
    final ref = data.refName(globalChapter, verse);
    final texts = _texts;
    final snippet = texts == null
        ? ''
        : texts.verseText(_translation, data, globalChapter, verse);
    return Semantics(
      container: true,
      button: true,
      label: 'Open $ref',
      child: Material(
        color: WwColors.surface,
        borderRadius: BorderRadius.circular(WwRadius.row),
        child: InkWell(
          borderRadius: BorderRadius.circular(WwRadius.row),
          onTap: () => widget.onOpenVerse(globalChapter, verse),
          child: Container(
            constraints: const BoxConstraints(minHeight: WwSpace.minTarget),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(ref, style: WwType.refLabelOnDark),
                      const SizedBox(height: 2),
                      Text(
                        snippet,
                        style: WwType.bodyOnDark,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: WwColors.mutedOnDark,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
