import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../data/ambient_stage.dart';
import '../data/bible_data.dart';
import '../data/plans.dart';
import '../data/tradition.dart';
import '../data/user_data.dart';
import '../data/verse_of_day.dart';
import '../theme/ww_theme.dart';
import '../widgets/arc_stage.dart';

/// The route observer for Home's own route (HOME ARCH GOES
/// AMBIENT, spec §5): the shell registers it on its navigators
/// so HomeTab's [RouteAware] callbacks learn when a route is
/// pushed above Home (rotation pauses) and when it pops
/// (rotation resumes). Standalone HomeTab trees (tests) may
/// register it on their own navigator the same way.
final RouteObserver<PageRoute<dynamic>> wwHomeRouteObserver =
    RouteObserver<PageRoute<dynamic>>();

/// The Home tab's root (board run 7 part B, §2): top bar with the
/// profile chip, the pinned AMBIENT arc stage (HOME ARCH GOES
/// AMBIENT: a self-running visual that features a new chapter
/// of the active canon every 3 seconds, with a caption naming
/// it and its connection count; tapping it opens the featured
/// chapter in the reader), and a scroll area holding, in order
/// (spec §1): Continue reading, Verse of the Day, Study Plans,
/// and Study Tools. The selection panel is REMOVED — chapter
/// taps open the reader directly, and connections live in the
/// reader. HomeTab renders the values it is handed; the shell
/// computes them (§7.1).
class HomeTab extends StatefulWidget {
  const HomeTab({
    super.key,
    required this.dataFuture,
    required this.userData,
    required this.tradition,
    required this.resumeBound,
    required this.resumeSubtitle,
    required this.notesCount,
    required this.verseOfDay,
    required this.plans,
    required this.highlightsCount,
    required this.onOpenChapter,
    required this.onResume,
    required this.onOpenProfiles,
    required this.onOpenMyNotes,
    required this.onOpenVerseOfDay,
    required this.onOpenPlan,
    required this.onCreatePlan,
    required this.onOpenHighlights,
    required this.onRetryLoad,
    this.ambientActive = true,
    this.ambientRandom,
  });

  final Future<BibleData> dataFuture;
  final UserData userData;

  /// The active tradition: the ambient pool and the stage range
  /// follow its canon (spec §2).
  final WwTradition tradition;

  /// Whether Home is the shell's selected tab (spec §5): Home
  /// lives in an IndexedStack, so hidden is not disposed — the
  /// shell passes its tab state and rotation pauses off-tab.
  final bool ambientActive;

  /// Test seam for the ambient picker (spec §3): the shell
  /// passes none and the picker uses a fresh `Random`.
  final math.Random? ambientRandom;
  final bool resumeBound;
  final String resumeSubtitle;
  final int notesCount;

  /// The Verse of the Day card's data (§3.3); null = no card.
  final VerseOfDayCardData? verseOfDay;

  /// Offered plans only, in definition order (§7.1); empty = no
  /// Study Plans section.
  final List<PlanCardData> plans;

  /// The visible span count behind the Highlights tool caption
  /// (§5): exactly the rows the All Highlights tap reveals.
  final int highlightsCount;

  final void Function(int ch) onOpenChapter;
  final VoidCallback onResume;
  final VoidCallback onOpenProfiles;
  final VoidCallback onOpenMyNotes;
  final void Function(int chapter, int verse) onOpenVerseOfDay;
  final void Function(String planId) onOpenPlan;
  final VoidCallback onCreatePlan;
  final VoidCallback onOpenHighlights;
  final VoidCallback onRetryLoad;

  @override
  State<HomeTab> createState() => HomeTabState();
}

class HomeTabState extends State<HomeTab>
    with TickerProviderStateMixin, WidgetsBindingObserver, RouteAware {
  static const _miniStage = Size(1200, 500);

  final _scrollCtl = ScrollController();
  final _images = <String, ui.Image>{};
  final _rendering = <String>{};

  // ------------------------------------------------ ambient stage

  /// The rotation driver (spec I-3): a frame ticker, not a
  /// Timer — TickerMode mutes it under a covering route, it
  /// dies with this State, and it leaves no pending-timer leak.
  late final Ticker _rotationTicker;

  /// The morph driver (spec §4): 600ms, eased in the painter.
  late final AnimationController _morph;

  Duration _lastFeature = Duration.zero;
  int? _featured;
  int? _previous;

  /// The picker pool, computed once per (data, tradition)
  /// (spec §2/§7), and the precomputed arc geometry, once per
  /// dataset (spec §7). A tick reads only these.
  List<int> _pool = const [];
  BibleData? _poolData;
  WwTradition? _poolTradition;
  Map<int, List<AmbientArc>> _geometry = const {};
  BibleData? _geometryData;
  AmbientPicker? _picker;

  /// Pause state (spec §5): plain fields, never setState —
  /// pausing and resuming start/stop the ticker only.
  bool _scrollActive = false;
  bool _pointerActive = false;
  bool _routeCovered = false;
  bool _foreground = true;
  bool _reducedMotion = false;
  PageRoute<dynamic>? _route;

  @override
  void initState() {
    super.initState();
    _rotationTicker = createTicker(_onRotationTick);
    _morph = AnimationController(
      vsync: this,
      duration: ambientMorphDuration,
      value: 1,
    );
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_route != null) wwHomeRouteObserver.unsubscribe(this);
    _rotationTicker.dispose();
    _morph.dispose();
    _scrollCtl.dispose();
    for (final img in _images.values) {
      img.dispose();
    }
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reducedMotion = MediaQuery.of(context).disableAnimations;
    if (_reducedMotion && _morph.isAnimating) _morph.value = 1;
    final route = ModalRoute.of(context);
    if (route is PageRoute<dynamic> && !identical(route, _route)) {
      if (_route != null) wwHomeRouteObserver.unsubscribe(this);
      _route = route;
      wwHomeRouteObserver.subscribe(this, route);
    }
    _syncRotation();
  }

  @override
  void didUpdateWidget(HomeTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncRotation();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _syncRotation();
  }

  @override
  void didPushNext() {
    _routeCovered = true;
    _syncRotation();
  }

  @override
  void didPopNext() {
    _routeCovered = false;
    _syncRotation();
  }

  bool get _shouldRotate =>
      widget.ambientActive &&
      _foreground &&
      !_routeCovered &&
      !_scrollActive &&
      !_pointerActive &&
      !_reducedMotion &&
      _pool.length > 1 &&
      _featured != null;

  /// Starts or stops the rotation ticker to match the pause
  /// matrix (spec §5). Resume always starts a fresh interval:
  /// the ticker's clock restarts, so no partial credit and no
  /// catch-up burst.
  void _syncRotation() {
    if (!mounted) return;
    if (_shouldRotate) {
      if (!_rotationTicker.isActive) {
        _lastFeature = Duration.zero;
        _rotationTicker.start();
      }
    } else {
      if (_rotationTicker.isActive) _rotationTicker.stop();
    }
  }

  void _onRotationTick(Duration elapsed) {
    if (elapsed - _lastFeature < ambientInterval) return;
    _lastFeature = elapsed;
    _rotate();
  }

  /// One feature change (spec §7): one picker draw over the
  /// cached pool, one state swap, the morph starts. Nothing
  /// scans the dataset here.
  void _rotate() {
    final picker = _picker;
    if (picker == null) return;
    final next = picker.next(_pool, _featured);
    if (next == null || next == _featured) return;
    setState(() {
      _previous = _featured;
      _featured = next;
    });
    if (!_reducedMotion) _morph.forward(from: 0);
  }

  /// Computes the cached pool/geometry when their inputs change
  /// and draws the initial feature (spec §2/§7). Runs inside
  /// build like the shipped image cache did; every write is
  /// guarded by the identity it caches on.
  void _ensureAmbient(BibleData data) {
    if (!identical(_geometryData, data)) {
      _geometryData = data;
      _geometry = buildAmbientArcGeometry(data);
      _poolData = null;
    }
    if (!identical(_poolData, data) || _poolTradition != widget.tradition) {
      _poolData = data;
      _poolTradition = widget.tradition;
      _pool = buildAmbientPool(data, widget.tradition).pool;
      _picker = AmbientPicker(widget.ambientRandom);
      if (_featured == null || !_pool.contains(_featured)) {
        _featured = _picker!.next(_pool, null);
        _previous = _featured;
        if (_morph.value != 1) _morph.value = 1;
      }
    }
  }

  void scrollToTop() {
    if (!_scrollCtl.hasClients) return;
    if (WwMotion.reduced(context)) {
      _scrollCtl.jumpTo(0);
    } else {
      _scrollCtl.animateTo(0, duration: WwMotion.push, curve: WwMotion.curve);
    }
  }

  Future<void> _ensureMiniImage({
    required String key,
    required BibleData data,
    required int lo,
    required int hi,
    required double band,
    required bool includeArcs,
  }) async {
    if (_images.containsKey(key) || _rendering.contains(key)) return;
    _rendering.add(key);
    try {
      final img = await renderArcImage(
        data: data,
        lo: lo,
        hi: hi,
        stage: _miniStage,
        density: band,
        faint: false,
        includeArcs: includeArcs,
        includeLabels: false,
      );
      _images[key] = img;
      if (mounted) setState(() {});
    } finally {
      _rendering.remove(key);
    }
  }

  static String _fmt(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WwColors.stage,
      body: SafeArea(
        // Any touch on Home pauses rotation until it lifts
        // (spec §5, interaction row): the Listener only
        // observes; it never consumes a gesture.
        child: Listener(
          onPointerDown: (_) {
            if (!_pointerActive) {
              _pointerActive = true;
              _syncRotation();
            }
          },
          onPointerUp: (_) {
            if (_pointerActive) {
              _pointerActive = false;
              _syncRotation();
            }
          },
          onPointerCancel: (_) {
            if (_pointerActive) {
              _pointerActive = false;
              _syncRotation();
            }
          },
          child: FutureBuilder<BibleData>(
            future: widget.dataFuture,
            builder: (context, snapshot) {
              final data = snapshot.data;
              if (data != null) {
                _ensureAmbient(data);
                _syncRotation();
              }
              return Column(
                children: [
                  _topBar(),
                  if (data != null) _ambientStage(data),
                  Expanded(
                    child: data != null
                        ? _scrollArea(data)
                        : _statusArea(snapshot),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _statusArea(AsyncSnapshot<BibleData> snapshot) {
    if (snapshot.hasError) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('The web could not be woven.', style: WwType.bodyOnDark),
            const SizedBox(height: 16),
            TextButton(
              onPressed: widget.onRetryLoad,
              style: TextButton.styleFrom(
                minimumSize: const Size(64, WwSpace.minTarget),
              ),
              child: Text(
                'Try again',
                style: WwType.buttonLabel.copyWith(color: WwColors.goldBright),
              ),
            ),
          ],
        ),
      );
    }
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Woven Word', style: WwType.screenTitle),
          SizedBox(height: 12),
          Text('Weaving 344,799 connections…', style: WwType.captionOnDark),
        ],
      ),
    );
  }

  Widget _topBar() {
    final profileName = widget.userData.profileName(
      widget.userData.activeProfileId,
    );
    final initial = profileName.trim().isEmpty
        ? '?'
        : profileName.trim()[0].toUpperCase();
    return Container(
      constraints: const BoxConstraints(minHeight: WwSpace.topBarHeight),
      padding: const EdgeInsets.symmetric(horizontal: WwSpace.screenMargin),
      decoration: const BoxDecoration(
        color: WwColors.nav,
        border: Border(bottom: BorderSide(color: WwColors.borderDarkSoft)),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Woven Word', style: WwType.appTitle),
                Text('BIBLE CROSS REFERENCES', style: WwType.appSubtitle),
              ],
            ),
          ),
          Semantics(
            button: true,
            label: 'Profiles',
            child: Material(
              color: Colors.transparent,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: widget.onOpenProfiles,
                child: SizedBox(
                  width: WwSpace.minTarget,
                  height: WwSpace.minTarget,
                  child: Center(
                    child: Tooltip(
                      message: 'Profiles',
                      child: Container(
                        width: 40,
                        height: 40,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                          color: WwColors.goldBright,
                          shape: BoxShape.circle,
                        ),
                        child: Text(initial, style: WwType.avatarLetterOnGold),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  (int, int) _range(BibleData data) => ambientRange(data, widget.tradition);

  /// The ambient stage (spec §4): the featured chapter's arcs
  /// over the shipped selection-state background (chapter bars,
  /// no ambient web), the caption under it, and ONE tap target
  /// for the whole stage + caption that opens the featured
  /// chapter in the reader through the shell's routing.
  Widget _ambientStage(BibleData data) {
    final (lo, hi) = _range(data);
    final featured = _featured;
    final caption = featured == null
        ? null
        : '${data.chapterName(featured)} · '
              '${_fmt(data.chapterConnCount[featured])} '
              '${data.chapterConnCount[featured] == 1 ? 'connection' : 'connections'}';
    return Semantics(
      key: const ValueKey('ambient-stage'),
      container: true,
      button: true,
      label: featured == null ? 'Arc stage' : 'Open ${data.chapterName(featured)}',
      child: ExcludeSemantics(
        child: Material(
          color: WwColors.stage,
          child: InkWell(
            onTap: featured == null
                ? null
                : () => widget.onOpenChapter(featured),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  decoration: const BoxDecoration(
                    color: WwColors.stage,
                    border: Border(
                      bottom: BorderSide(color: WwColors.borderDarkSoft),
                    ),
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final w = constraints.maxWidth;
                      final band = bandFor(densityFor(w));
                      const includeArcs = false;
                      final key = '$lo-$hi-$band-$includeArcs';
                      final img = _images[key];
                      if (img == null) {
                        _ensureMiniImage(
                          key: key,
                          data: data,
                          lo: lo,
                          hi: hi,
                          band: band,
                          includeArcs: includeArcs,
                        );
                      }
                      return SizedBox(
                        width: w,
                        height: w * _miniStage.height / _miniStage.width,
                        child: FittedBox(
                          fit: BoxFit.fill,
                          child: SizedBox(
                            width: _miniStage.width,
                            height: _miniStage.height,
                            child: Stack(
                              children: [
                                if (img != null)
                                  RawImage(
                                    image: img,
                                    width: _miniStage.width,
                                    height: _miniStage.height,
                                    fit: BoxFit.fill,
                                  ),
                                if (featured != null)
                                  Positioned.fill(
                                    child: AnimatedBuilder(
                                      animation: _morph,
                                      builder: (context, _) => CustomPaint(
                                        painter: AmbientArcPainter(
                                          data: data,
                                          lo: lo,
                                          hi: hi,
                                          stage: _miniStage,
                                          fromChapter: _previous,
                                          toChapter: featured,
                                          fromArcs: _previous == null
                                              ? const []
                                              : (_geometry[_previous] ??
                                                    const []),
                                          toArcs:
                                              _geometry[featured] ?? const [],
                                          t: _reducedMotion
                                              ? 1
                                              : Curves.easeInOut.transform(
                                                  _morph.value,
                                                ),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Container(
                  key: const ValueKey('ambient-caption'),
                  constraints: const BoxConstraints(
                    minHeight: WwSpace.minTarget,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: WwSpace.screenMargin,
                  ),
                  alignment: Alignment.centerLeft,
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: WwColors.borderDarkSoft),
                    ),
                  ),
                  child: caption == null
                      ? const SizedBox.shrink()
                      : Text(caption, style: WwType.captionOnDark),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _scrollArea(BibleData data) {
    // Scrolling anywhere inside Home — the main list or the
    // plan row — pauses rotation (spec §5): notifications from
    // every descendant scrollable bubble through here.
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollStartNotification) {
          if (!_scrollActive) {
            _scrollActive = true;
            _syncRotation();
          }
        } else if (notification is ScrollEndNotification) {
          if (_scrollActive) {
            _scrollActive = false;
            _syncRotation();
          }
        }
        return false;
      },
      child: ListView(
        controller: _scrollCtl,
        padding: const EdgeInsets.only(top: 16),
        children: [
          _resumeCard(),
          if (widget.verseOfDay != null) ...[
            const SizedBox(height: 16),
            _verseOfDayCard(),
          ],
          const SizedBox(height: 16),
          _plansSection(data),
          const SizedBox(height: 16),
          _toolsSection(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _placeRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: WwSpace.screenMargin),
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
                Icon(icon, size: 20, color: WwColors.goldBright),
                const SizedBox(width: 12),
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

  Widget _resumeCard() {
    return _placeRow(
      icon: Icons.menu_book,
      title: widget.resumeBound ? 'Continue reading' : 'Start reading',
      subtitle: widget.resumeSubtitle,
      onTap: widget.onResume,
    );
  }

  // ------------------------------------------------ Verse of the Day

  /// The Verse of the Day card (run 11, §3.4): the whole card is
  /// the one tap target, opening the reader at the pick via the
  /// shell's callback. While the texts load (or after they fail)
  /// the label, reference, and count render as usual and the
  /// verse-text slot carries the pinned loading/failure string.
  Widget _verseOfDayCard() {
    final vod = widget.verseOfDay!;
    final hasText = vod.text != null && vod.text!.isNotEmpty;
    final bodyText = vod.text == null
        ? "Loading today's verse…"
        : vod.text!.isEmpty
        ? "Today's verse text could not be loaded."
        : vod.text!;
    final countCaption = vod.connectionCount == 1
        ? '1 connection'
        : '${_fmt(vod.connectionCount)} connections';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: WwSpace.screenMargin),
      child: Semantics(
        container: true,
        button: true,
        label: 'Verse of the Day, ${vod.reference}',
        child: ExcludeSemantics(
          child: Material(
            key: const ValueKey('votd-card'),
            color: WwColors.surface,
            borderRadius: BorderRadius.circular(WwRadius.row),
            child: InkWell(
              borderRadius: BorderRadius.circular(WwRadius.row),
              onTap: () => widget.onOpenVerseOfDay(vod.chapter, vod.verse),
              child: Container(
                padding: const EdgeInsets.all(WwSpace.screenMargin),
                width: double.infinity,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('VERSE OF THE DAY', style: WwType.appSubtitle),
                    const SizedBox(height: 8),
                    Text(
                      bodyText,
                      style: hasText
                          ? WwType.verseOfDayBody
                          : WwType.captionOnDark,
                      textDirection: hasText && vod.translation.isRtl
                          ? TextDirection.rtl
                          : null,
                    ),
                    const SizedBox(height: 8),
                    Text(vod.reference, style: WwType.refLabelOnDark),
                    const SizedBox(height: 4),
                    Text(countCaption, style: WwType.captionOnDark),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------ Study Plans

  Widget _plansSection(BibleData data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: WwSpace.screenMargin),
          child: Text('STUDY PLANS', style: WwType.appSubtitle),
        ),
        const SizedBox(height: 16),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: WwSpace.screenMargin),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < widget.plans.length; i++) ...[
                  if (i > 0) const SizedBox(width: 12),
                  _planCard(data, widget.plans[i]),
                ],
                if (widget.plans.isNotEmpty) const SizedBox(width: 12),
                _createTile(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// One plan card (run 11, §4.4): a typographic cover (no
  /// artwork), the title and caption under it, and — only when
  /// the plan is started — the progress bar across the cover's
  /// bottom edge. The whole card is one tap target.
  Widget _planCard(BibleData data, PlanCardData card) {
    final plan = card.plan;
    final caption = !card.started
        ? '${plan.days} days · ${_fmt(plan.totalChapters)} chapters'
        : card.doneCount == plan.totalChapters
        ? 'Complete · 100%'
        : 'Day ${card.currentDay} of ${plan.days} · ${card.percent}%';
    final List<String> bookLines;
    if (plan.coverBooks.length > 4) {
      bookLines = [
        data.books[plan.coverBooks.first].name,
        '…',
        data.books[plan.coverBooks.last].name,
      ];
    } else {
      bookLines = [for (final b in plan.coverBooks) data.books[b].name];
    }
    return Semantics(
      container: true,
      button: true,
      label: '${plan.name}, $caption',
      child: ExcludeSemantics(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(WwRadius.row),
            onTap: () => widget.onOpenPlan(plan.id),
            child: SizedBox(
              width: 112,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // The cover is fixed-geometry artwork (112 × 144,
                  // §4.4/§10): its book lines and meta are set in
                  // the cover's own scale, clamped at 1.0, because
                  // at text scale 2.0 four serif lines at the
                  // ambient 1.43 height measure ~149dp against the
                  // cover's 118dp inner height and overflow the
                  // pinned box (§10's no-overflow rule). The plan
                  // name and caption directly beneath the cover
                  // carry the same words at the user's full scale.
                  MediaQuery(
                    data: MediaQuery.of(context).copyWith(
                      textScaler: MediaQuery.of(context).textScaler
                          .clamp(maxScaleFactor: 1.0),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(WwRadius.row),
                      child: Stack(
                        children: [
                          Container(
                            key: ValueKey('plan-cover-${plan.id}'),
                            width: 112,
                            height: 144,
                            decoration: BoxDecoration(
                              color: WwColors.surfaceHigh,
                              border: Border.all(color: WwColors.borderDark),
                              borderRadius: BorderRadius.circular(WwRadius.row),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 24,
                                    height: 2,
                                    color: WwColors.gold,
                                  ),
                                  const SizedBox(height: 8),
                                  for (final line in bookLines)
                                    Text(
                                      line,
                                      style: WwType.planCoverBook,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  const Expanded(child: SizedBox()),
                                  Text(
                                    '${_fmt(plan.totalChapters)} chapters',
                                    style: WwType.planCoverMeta,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (card.started)
                            Positioned(
                              left: 0,
                              right: 0,
                              bottom: 0,
                              height: 4,
                              child: Container(
                                key: ValueKey('plan-progress-${plan.id}'),
                                child: Stack(
                                  children: [
                                    Container(color: WwColors.borderDark),
                                    SizedBox(
                                      width:
                                          112 *
                                          card.doneCount /
                                          plan.totalChapters,
                                      height: 4,
                                      child: Container(
                                        color: WwColors.goldBright,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    plan.name,
                    style: WwType.controlLabel.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    caption,
                    style: WwType.captionOnDark,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// The create tile (spec §5.4): always the row's last child.
  Widget _createTile() {
    return Semantics(
      container: true,
      button: true,
      label: 'Create your own plan, Choose books and a pace',
      child: ExcludeSemantics(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(WwRadius.row),
            onTap: widget.onCreatePlan,
            child: SizedBox(
              width: 112,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    key: const ValueKey('plan-cover-create'),
                    width: 112,
                    height: 144,
                    decoration: BoxDecoration(
                      color: WwColors.surfaceHigh,
                      border: Border.all(color: WwColors.borderDark),
                      borderRadius: BorderRadius.circular(WwRadius.row),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(width: 24, height: 2, color: WwColors.gold),
                          const Expanded(
                            child: Center(
                              child: Icon(
                                Icons.add,
                                size: 32,
                                color: WwColors.goldBright,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Create your own plan',
                    style: WwType.controlLabel.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Choose books and a pace',
                    style: WwType.captionOnDark,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------ Study Tools

  Widget _toolsSection() {
    final notes = widget.notesCount;
    final notesCaption = notes == 0
        ? 'No notes yet'
        : notes == 1
        ? '1 note'
        : '$notes notes';
    final highlights = widget.highlightsCount;
    final highlightsCaption = highlights == 0
        ? 'No highlights yet'
        : highlights == 1
        ? '1 highlight'
        : '$highlights highlights';
    final profileName = widget.userData.profileName(
      widget.userData.activeProfileId,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: WwSpace.screenMargin),
          child: Text('STUDY TOOLS', style: WwType.appSubtitle),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: WwSpace.screenMargin),
          child: Material(
            color: WwColors.surface,
            borderRadius: BorderRadius.circular(WwRadius.row),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _toolEntry(
                    key: const ValueKey('tool-my-notes'),
                    icon: Icons.notes,
                    label: 'My Notes',
                    caption: notesCaption,
                    onTap: widget.onOpenMyNotes,
                  ),
                  _toolEntry(
                    key: const ValueKey('tool-highlights'),
                    icon: Icons.highlight,
                    label: 'Highlights',
                    caption: highlightsCaption,
                    onTap: widget.onOpenHighlights,
                  ),
                  _toolEntry(
                    key: const ValueKey('tool-profiles'),
                    icon: Icons.person_outline,
                    label: 'Profiles',
                    caption: profileName,
                    captionMaxLines: 1,
                    onTap: widget.onOpenProfiles,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// One Study Tools entry (run 11, §5): icon over label over
  /// caption, centered in its third of the card; the entry's hit
  /// area is its full column.
  Widget _toolEntry({
    required ValueKey<String> key,
    required IconData icon,
    required String label,
    required String caption,
    required VoidCallback onTap,
    int captionMaxLines = 2,
  }) {
    return Expanded(
      child: Semantics(
        container: true,
        button: true,
        label: '$label, $caption',
        child: ExcludeSemantics(
          child: InkWell(
            key: key,
            borderRadius: BorderRadius.circular(WwRadius.row),
            onTap: onTap,
            child: Container(
              constraints: const BoxConstraints(minHeight: WwSpace.minTarget),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 24, color: WwColors.goldBright),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    style: WwType.controlLabel.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    caption,
                    style: WwType.captionOnDark,
                    textAlign: TextAlign.center,
                    maxLines: captionMaxLines,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
