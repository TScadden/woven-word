import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:woven_word/data/bible_data.dart';
import 'package:woven_word/data/conference_data.dart';
import 'package:woven_word/data/scripture_text.dart';
import 'package:woven_word/screens/conference_screens.dart';
import 'package:woven_word/screens/library_tab.dart';
import 'package:woven_word/theme/ww_theme.dart';

import 'fake_canon.dart';

/// Board run 8, spec §4 / §7: the Library conference browse —
/// root tile (ON-only, dataset-non-empty, counts counted at
/// render), conferences list, talks list, and the talk view's
/// routed read action in its forms (Gospel Library per-talk /
/// Citation Index / residual conference fallback / neither —
/// §4.4.1 as amended Oct 14, 2026). All semantics labels are
/// asserted against the semantics tree (lesson 25).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late BibleData data;
  late ScriptureText texts;
  late ConferenceData conf;

  setUp(() {
    data = fakeReaderData();
    texts = fakeReaderTexts(data);
    final source = File(
      'test/fixtures/conference_fixture.json',
    ).readAsStringSync();
    conf = ConferenceData.fromCanon(source, data);
  });

  Future<void> pumpApp(
    WidgetTester tester,
    Widget home, {
    Size size = const Size(360, 800),
    bool disableAnimations = false,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      MaterialApp(
        theme: wwTheme(),
        builder: (context, child) {
          var mq = MediaQuery.of(context);
          if (disableAnimations) {
            mq = mq.copyWith(disableAnimations: true);
          }
          return MediaQuery(data: mq, child: child!);
        },
        home: home,
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump();
  }

  group('Library root tile (§4.1)', () {
    LibraryRoot root(ConferenceLayerState? state, VoidCallback? onOpen) {
      return LibraryRoot(
        dataFuture: Future.value(data),
        onTestament: (_) {},
        onOpenChapter: (_) {},
        conferenceState: state,
        onOpenConference: onOpen,
      );
    }

    testWidgets('OFF: exactly the two shipped testament tiles', (
      tester,
    ) async {
      await pumpApp(
        tester,
        root(_FakeState(false, conf), () {}),
      );
      expect(find.text('Old Testament'), findsOneWidget);
      expect(find.text('New Testament'), findsOneWidget);
      expect(find.text('General Conference'), findsNothing);
      expect(
        find.bySemanticsLabel('General Conference, 5 conferences, 8 talks'),
        findsNothing,
      );
    });

    testWidgets('no state supplied: the shipped root, exactly', (
      tester,
    ) async {
      await pumpApp(tester, root(null, null));
      expect(find.text('Old Testament'), findsOneWidget);
      expect(find.text('New Testament'), findsOneWidget);
      expect(find.text('General Conference'), findsNothing);
    });

    testWidgets('ON: tile with counts counted from the dataset, '
        'semantics label, tap fires', (tester) async {
      final semantics = tester.ensureSemantics();
      var taps = 0;
      await pumpApp(tester, root(_FakeState(true, conf), () => taps++));
      expect(find.text('General Conference'), findsOneWidget);
      expect(find.text('5 conferences · 8 talks'), findsOneWidget);
      expect(
        find.bySemanticsLabel('General Conference, 5 conferences, 8 talks'),
        findsOneWidget,
      );
      await tester.tap(find.text('General Conference'));
      await tester.pump();
      expect(taps, 1);
      semantics.dispose();
    });

    testWidgets('ON but dataset empty: the tile does not render', (
      tester,
    ) async {
      final empty = ConferenceData.parse(
        '{"v":1,"talks":[],"edges":[]}',
        chapterVerseCounts: [for (final c in data.chapters) c.v],
        chapters: data.chapters,
      );
      await pumpApp(tester, root(_FakeState(true, empty), () {}));
      expect(find.text('Old Testament'), findsOneWidget);
      expect(find.text('General Conference'), findsNothing);
    });
  });

  group('Conferences list (§4.2)', () {
    Future<void> pumpList(
      WidgetTester tester, {
      ConferenceData? use,
      List<(int, String)>? opened,
    }) {
      return pumpApp(
        tester,
        ConferenceListScreen(
          conferenceData: use ?? conf,
          onBack: () {},
          onBreadcrumbRoot: () {},
          onOpenConference: (y, s) => opened?.add((y, s)),
        ),
        size: const Size(360, 1200),
      );
    }

    testWidgets('intro caption, newest-first rows with counted '
        'subtitles, attribution footer', (tester) async {
      await pumpList(tester);
      expect(
        find.text(
          'Newest first. Talk counts include only talks that cite '
          'the Bible.',
        ),
        findsOneWidget,
      );
      // Newest first: October before April within 2024 (§3.3/§4.2).
      final oct24 = tester.getTopLeft(find.text('October 2024')).dy;
      final apr24 = tester.getTopLeft(find.text('April 2024')).dy;
      final oct23 = tester.getTopLeft(find.text('October 2023')).dy;
      final oct19 = tester.getTopLeft(find.text('October 2019')).dy;
      final oct90 = tester.getTopLeft(find.text('October 1990')).dy;
      expect(oct24 < apr24, isTrue);
      expect(apr24 < oct23, isTrue);
      expect(oct23 < oct19, isTrue);
      expect(oct19 < oct90, isTrue);
      expect(find.text('3 talks'), findsOneWidget);
      expect(find.text('2 talks'), findsOneWidget);
      expect(find.text('1 talk'), findsNWidgets(3));
      expect(
        find.text(
          'Citation facts are from the Scripture Citation Index '
          '(scriptures.byu.edu), compiled by Richard C. Galbraith '
          'and Stephen W. Liddle.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('row semantics exact, tap reports the conference', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      final opened = <(int, String)>[];
      await pumpList(tester, opened: opened);
      expect(
        find.bySemanticsLabel('Open October 2024 conference, 3 talks'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('Open October 2023 conference, 1 talk'),
        findsOneWidget,
      );
      await tester.tap(
        find.bySemanticsLabel('Open October 2024 conference, 3 talks'),
      );
      await tester.pump();
      expect(opened, [(2024, 'O')]);
      semantics.dispose();
    });

    testWidgets('a conference with zero citing talks is absent '
        'as rendered', (tester) async {
      final zero = ConferenceData.parse(
        '{"v":1,"talks":['
        '{"i":0,"t":"Citing Talk","s":"S","y":2025,"e":"O","n":"N",'
        '"u":null,"c":0},'
        '{"i":1,"t":"No Citations","s":"S","y":2020,"e":"A","n":"N",'
        '"u":null,"c":0}'
        '],"edges":[[0,0,1]]}',
        chapterVerseCounts: [for (final c in data.chapters) c.v],
        chapters: data.chapters,
      );
      await pumpList(tester, use: zero);
      expect(find.text('October 2025'), findsOneWidget);
      expect(find.text('April 2020'), findsNothing);
    });
  });

  group('Talks list (§4.3)', () {
    testWidgets('dataset session order (never title order), '
        'subtitles count distinct cited verses, semantics exact', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      ConferenceTalk? openedTalk;
      await pumpApp(
        tester,
        ConferenceTalksScreen(
          conferenceData: conf,
          year: 2024,
          session: 'O',
          onBack: () {},
          onBreadcrumb: (_) {},
          onOpenTalk: (t) => openedTalk = t,
        ),
        size: const Size(360, 1200),
      );
      // Dataset order for 2024 October is Wada (1), Freeman (3),
      // Bednar (7). Title order would put 'Be Still…' first.
      const wada = 'The Words of Christ and the Holy Ghost Will '
          'Lead Us to the Truth';
      final wadaY = tester.getTopLeft(find.text(wada)).dy;
      final freemanY = tester
          .getTopLeft(find.text('Live Up to Your Privileges'))
          .dy;
      final bednarY = tester
          .getTopLeft(find.text('Be Still, and Know That I Am God'))
          .dy;
      expect(wadaY < freemanY, isTrue);
      expect(freemanY < bednarY, isTrue);
      expect(find.text('Takashi Wada · 5 scriptures'), findsOneWidget);
      expect(
        find.text('Emily Belle Freeman · 2 scriptures'),
        findsOneWidget,
      );
      expect(find.text('David A. Bednar · 2 scriptures'), findsOneWidget);
      expect(
        find.bySemanticsLabel(
          'Open talk: Live Up to Your Privileges, by Emily Belle Freeman',
        ),
        findsOneWidget,
      );
      await tester.tap(
        find.bySemanticsLabel(
          'Open talk: Live Up to Your Privileges, by Emily Belle Freeman',
        ),
      );
      await tester.pump();
      expect(openedTalk?.id, 3);
      semantics.dispose();
    });

    testWidgets('a talk with no Bible citation is not listed', (
      tester,
    ) async {
      final mixed = ConferenceData.parse(
        '{"v":1,"talks":['
        '{"i":0,"t":"Citing Talk","s":"Ann","y":2025,"e":"O","n":"N",'
        '"u":null,"c":0},'
        '{"i":1,"t":"Silent Talk","s":"Bob","y":2025,"e":"O","n":"N",'
        '"u":null,"c":0}'
        '],"edges":[[0,0,1]]}',
        chapterVerseCounts: [for (final c in data.chapters) c.v],
        chapters: data.chapters,
      );
      await pumpApp(
        tester,
        ConferenceTalksScreen(
          conferenceData: mixed,
          year: 2025,
          session: 'O',
          onBack: () {},
          onBreadcrumb: (_) {},
          onOpenTalk: (_) {},
        ),
      );
      expect(find.text('Citing Talk'), findsOneWidget);
      expect(find.text('Silent Talk'), findsNothing);
      expect(find.text('Ann · 1 scripture'), findsOneWidget);
    });

    testWidgets('safety empty state: C-23 verbatim', (tester) async {
      await pumpApp(
        tester,
        ConferenceTalksScreen(
          conferenceData: conf,
          year: 2000,
          session: 'A',
          onBack: () {},
          onBreadcrumb: (_) {},
          onOpenTalk: (_) {},
        ),
      );
      expect(
        find.text('No talks are listed for this conference.'),
        findsOneWidget,
      );
    });
  });

  group('Talk view (§4.4)', () {
    Future<void> pumpTalk(
      WidgetTester tester,
      ConferenceTalk talk, {
      Future<bool> Function(Uri)? launcher,
      void Function(int, int?)? onOpenVerse,
    }) {
      return pumpApp(
        tester,
        TalkViewScreen(
          data: data,
          conferenceData: conf,
          talk: talk,
          onBack: () {},
          onBreadcrumb: (_) {},
          onOpenVerse: onOpenVerse ?? (_, _) {},
          textsLoader: () async => texts,
          externalLauncher: launcher,
        ),
        size: const Size(360, 2000),
      );
    }

    testWidgets('Form A: header block, gold action with Form A '
        'semantics, one row per distinct verse in canon order, '
        'C-21 and C-22 verbatim', (tester) async {
      final semantics = tester.ensureSemantics();
      final wada = conf.talkById(1)!;
      (int, int?)? opened;
      await pumpTalk(tester, wada, onOpenVerse: (ch, v) => opened = (ch, v));
      expect(find.text(wada.title), findsWidgets);
      expect(find.text('Takashi Wada'), findsOneWidget);
      expect(find.text('October 2024 General Conference'), findsOneWidget);
      expect(find.text('Read in Gospel Library'), findsOneWidget);
      // Wada's row also carries an Index page: the per-talk Gospel
      // Library link wins the routing (precedence is data-driven).
      expect(find.text('Read in Citation Index'), findsNothing);
      expect(
        find.bySemanticsLabel(
          'Read ${wada.title} in Gospel Library, opens external '
          'app or website',
        ),
        findsOneWidget,
      );
      // No fallback caption, no no-link caption on Form A.
      expect(
        find.text(
          'This talk has no direct link, so this opens its '
          'conference in Gospel Library.',
        ),
        findsNothing,
      );
      expect(
        find.text('This talk is not linked in Gospel Library.'),
        findsNothing,
      );
      expect(find.text('Scriptures cited'), findsOneWidget);
      // One row per distinct verse (§4.4.2): Wada cites Genesis
      // 1:1, Psalms 23:1, Psalms 119:105, John 1:1 and John 1:9 —
      // five rows, John 1:1 and John 1:9 as SEPARATE rows.
      for (final ref in [
        'Genesis 1:1',
        'Psalms 23:1',
        'Psalms 119:105',
        'John 1:1',
        'John 1:9',
      ]) {
        expect(find.text(ref), findsOneWidget, reason: ref);
        expect(
          find.bySemanticsLabel('Open $ref'),
          findsOneWidget,
          reason: 'semantics for $ref',
        );
      }
      final genY = tester.getTopLeft(find.text('Genesis 1:1')).dy;
      final psY = tester.getTopLeft(find.text('Psalms 23:1')).dy;
      final ps119Y = tester.getTopLeft(find.text('Psalms 119:105')).dy;
      final john1Y = tester.getTopLeft(find.text('John 1:1')).dy;
      final john9Y = tester.getTopLeft(find.text('John 1:9')).dy;
      expect(genY < psY, isTrue);
      expect(psY < ps119Y, isTrue);
      expect(ps119Y < john1Y, isTrue);
      expect(john1Y < john9Y, isTrue);
      // Snippets come from the active translation's own text.
      expect(find.textContaining('KJV John 1:9'), findsOneWidget);
      expect(find.textContaining('KJV Genesis 1:1'), findsOneWidget);
      // C-21 and C-22, verbatim, in that order.
      const c21 = 'This list shows Bible citations only. The talk '
          'may also cite the Book of Mormon, Doctrine and '
          'Covenants, Pearl of Great Price, and other sources, '
          'which this Bible app does not list.';
      const c22 = 'Citation facts are from the Scripture Citation '
          'Index (scriptures.byu.edu), compiled by Richard C. '
          'Galbraith and Stephen W. Liddle.';
      expect(find.text(c21), findsOneWidget);
      expect(find.text(c22), findsOneWidget);
      expect(
        tester.getTopLeft(find.text(c21)).dy <
            tester.getTopLeft(find.text(c22)).dy,
        isTrue,
      );
      // A scripture row tap opens the reader at that verse.
      await tester.tap(find.bySemanticsLabel('Open John 1:9'));
      await tester.pump();
      expect(opened, (data.books[42].start, 9));
      semantics.dispose();
    });

    testWidgets('Form C: a c:1 talk with an Index page routes to '
        'the Citation Index (amended §4.4.1) — Index label and '
        'semantics naming the Index, no Form B caption, launch '
        'uses the talk’s own Index page', (tester) async {
      final semantics = tester.ensureSemantics();
      final cook = conf.talkById(4)!;
      Uri? launched;
      await pumpTalk(
        tester,
        cook,
        launcher: (uri) async {
          launched = uri;
          return true;
        },
      );
      expect(find.text('Read in Citation Index'), findsOneWidget);
      expect(find.text('Read in Gospel Library'), findsNothing);
      expect(
        find.text('Open this conference in Gospel Library'),
        findsNothing,
      );
      expect(
        find.text(
          'This talk has no direct link, so this opens its '
          'conference in Gospel Library.',
        ),
        findsNothing,
      );
      expect(
        find.bySemanticsLabel(
          'Read ${cook.title} in the Scripture Citation Index, '
          'opens external app or website',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Read in Citation Index'));
      await tester.pump();
      await tester.pump();
      expect(
        launched.toString(),
        'https://scriptures.byu.edu/content/talks_ajax/8500/',
      );
      expect(find.byType(SnackBar), findsNothing);
      semantics.dispose();
    });

    testWidgets('Form C launch failure lands in the C-26 snackbar '
        'naming the Citation Index', (tester) async {
      final cook = conf.talkById(4)!;
      await pumpTalk(tester, cook, launcher: (uri) async => false);
      await tester.tap(find.text('Read in Citation Index'));
      await tester.pump();
      await tester.pump();
      expect(
        find.text('Could not open the Citation Index.'),
        findsOneWidget,
      );
      expect(find.text('Could not open Gospel Library.'), findsNothing);
    });

    testWidgets('Form B (residual): a conference-level link with '
        'NO Index page keeps the conference form — label, '
        'mandatory C-18 caption, Form B semantics, launch uses '
        'the conference link', (tester) async {
      final semantics = tester.ensureSemantics();
      const residual = ConferenceTalk(
        id: 998,
        title: 'Residual Talk',
        speaker: 'No Index Page',
        year: 2020,
        session: 'A',
        sessionName: 'Saturday Morning',
        url: 'https://www.churchofjesuschrist.org/study/'
            'general-conference/2020/04?lang=eng',
        urlIsConference: true,
      );
      Uri? launched;
      await pumpTalk(
        tester,
        residual,
        launcher: (uri) async {
          launched = uri;
          return true;
        },
      );
      expect(
        find.text('Open this conference in Gospel Library'),
        findsOneWidget,
      );
      expect(find.text('Read in Gospel Library'), findsNothing);
      expect(find.text('Read in Citation Index'), findsNothing);
      expect(
        find.text(
          'This talk has no direct link, so this opens its '
          'conference in Gospel Library.',
        ),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(
          'Open the April 2020 conference in Gospel Library, '
          'opens external app or website',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Open this conference in Gospel Library'));
      await tester.pump();
      await tester.pump();
      expect(launched.toString(), contains('/general-conference/2020/04'));
      expect(find.byType(SnackBar), findsNothing);
      semantics.dispose();
    });

    testWidgets('launch failure lands in the C-20 snackbar', (
      tester,
    ) async {
      final wada = conf.talkById(1)!;
      await pumpTalk(tester, wada, launcher: (uri) async => false);
      await tester.tap(find.text('Read in Gospel Library'));
      await tester.pump();
      await tester.pump();
      expect(find.text('Could not open Gospel Library.'), findsOneWidget);
    });

    testWidgets('a throwing launcher also lands in the snackbar', (
      tester,
    ) async {
      final wada = conf.talkById(1)!;
      await pumpTalk(
        tester,
        wada,
        launcher: (uri) async => throw StateError('no handler'),
      );
      await tester.tap(find.text('Read in Gospel Library'));
      await tester.pump();
      await tester.pump();
      expect(find.text('Could not open Gospel Library.'), findsOneWidget);
    });

    testWidgets('no-link talk: no button, C-19 in its place', (
      tester,
    ) async {
      final freeman = conf.talkById(3)!;
      await pumpTalk(tester, freeman);
      expect(find.byType(ElevatedButton), findsNothing);
      expect(find.text('Read in Citation Index'), findsNothing);
      expect(
        find.text('This talk is not linked in Gospel Library.'),
        findsOneWidget,
      );
      expect(
        find.text(
          'This talk has no direct link, so this opens its '
          'conference in Gospel Library.',
        ),
        findsNothing,
      );
      // The scripture list and honesty copy still render.
      expect(find.text('Scriptures cited'), findsOneWidget);
      expect(find.text('John 1:1'), findsOneWidget);
      expect(find.text('Psalms 1:1'), findsOneWidget);
    });

    testWidgets('safety empty state: C-24 with C-21 and C-22 '
        'still below it', (tester) async {
      const ghost = ConferenceTalk(
        id: 999,
        title: 'Ghost Talk',
        speaker: 'No One',
        year: 2020,
        session: 'A',
        sessionName: 'Saturday Morning',
        url: null,
        urlIsConference: false,
      );
      await pumpTalk(tester, ghost);
      expect(
        find.text('No Bible verses are listed for this talk.'),
        findsOneWidget,
      );
      expect(
        find.textContaining('This list shows Bible citations only.'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Citation facts are from the Scripture'),
        findsOneWidget,
      );
    });
  });

  group('Reduced motion (§8)', () {
    testWidgets('pushes present their content with animations '
        'disabled', (tester) async {
      await pumpApp(
        tester,
        Builder(
          builder: (context) => Center(
            child: TextButton(
              onPressed: () => Navigator.of(context).push(
                WwPageRoute(
                  builder: (_) => ConferenceListScreen(
                    conferenceData: conf,
                    onBack: () => Navigator.of(context).pop(),
                    onBreadcrumbRoot: () {},
                    onOpenConference: (y, s) =>
                        Navigator.of(context).push(
                          WwPageRoute(
                            builder: (_) => ConferenceTalksScreen(
                              conferenceData: conf,
                              year: y,
                              session: s,
                              onBack: () => Navigator.of(context).pop(),
                              onBreadcrumb: (_) {},
                              onOpenTalk: (talk) =>
                                  Navigator.of(context).push(
                                    WwPageRoute(
                                      builder: (_) => TalkViewScreen(
                                        data: data,
                                        conferenceData: conf,
                                        talk: talk,
                                        onBack: () =>
                                            Navigator.of(context).pop(),
                                        onBreadcrumb: (_) {},
                                        onOpenVerse: (_, _) {},
                                        textsLoader: () async => texts,
                                      ),
                                    ),
                                  ),
                            ),
                          ),
                        ),
                  ),
                ),
              ),
              child: const Text('Enter'),
            ),
          ),
        ),
        disableAnimations: true,
      );
      await tester.tap(find.text('Enter'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump();
      expect(
        find.text(
          'Newest first. Talk counts include only talks that cite '
          'the Bible.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('October 2024'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump();
      expect(find.text('Live Up to Your Privileges'), findsOneWidget);
      await tester.tap(find.text('Be Still, and Know That I Am God'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump();
      await tester.pump();
      expect(find.text('Scriptures cited'), findsOneWidget);
      expect(find.text('Read in Gospel Library'), findsOneWidget);
    });
  });
}

class _FakeState implements ConferenceLayerState {
  _FakeState(this.enabled, this.data);
  final bool enabled;
  final ConferenceData? data;
  @override
  bool get conferenceEnabled => enabled;
  @override
  ConferenceData? get conferenceData => data;
}
