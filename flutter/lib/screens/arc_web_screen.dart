import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../data/bible_data.dart';
import '../theme/ww_theme.dart';
import '../widgets/arc_stage.dart';

/// Screen (a): the arc web home.
///
/// The stage is a fixed logical canvas (1800 x 1120, poster geometry)
/// inside an InteractiveViewer: pinch to zoom, drag to pan, double-tap
/// or the reset button to return to the full fit. Arc brightness is
/// density-aware: at full fit the web renders as faint wisps (the
/// poster look); as you zoom, the pre-rendered arc layer steps up
/// through density bands and the threads brighten.
class ArcWebScreen extends StatefulWidget {
  const ArcWebScreen({super.key});

  @override
  State<ArcWebScreen> createState() => _ArcWebScreenState();
}

class _ArcWebScreenState extends State<ArcWebScreen>
    with SingleTickerProviderStateMixin {
  static const _stageSize = Size(1800, 1120);

  BibleData? _data;
  Object? _error;
  String _scope = 'all';
  int? _selected;

  final _transform = TransformationController();
  final _searchCtl = TextEditingController();
  double _scale = 0.2;
  double _fitScale = 0.2;
  bool _viewInitialized = false;
  Matrix4 _homeMatrix = Matrix4.identity();

  final _images = <String, ui.Image>{};
  final _rendering = <String>{};
  double _renderedBand = 0.22;

  AnimationController? _anim;
  Matrix4Tween? _animTween;

  @override
  void initState() {
    super.initState();
    _transform.addListener(_onTransform);
    _load();
  }

  @override
  void dispose() {
    _transform.removeListener(_onTransform);
    _transform.dispose();
    _searchCtl.dispose();
    _anim?.dispose();
    for (final img in _images.values) {
      img.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final data = await BibleData.load();
      if (!mounted) return;
      setState(() {
        _data = data;
        _error = null;
      });
      _ensureImage(faint: false);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  void _onTransform() {
    final s = _transform.value.getMaxScaleOnAxis();
    if ((s - _scale).abs() > 0.001 && mounted) setState(() => _scale = s);
  }

  (int, int) get _range => _data!.scopeRange(_scope);

  ArcGeometry get _geometry {
    final (lo, hi) = _range;
    final data = _data!;
    return ArcGeometry(
      _stageSize,
      data.chapterStart[lo],
      data.chapterStart[hi] + data.chapters[hi].v,
    );
  }

  String _key(bool faint, double band) {
    final (lo, hi) = _range;
    return '$lo-$hi-$band-$faint';
  }

  Future<void> _ensureImage({required bool faint, double? band}) async {
    final data = _data;
    if (data == null) return;
    final b = band ?? _renderedBand;
    final key = _key(faint, b);
    if (_images.containsKey(key) || _rendering.contains(key)) return;
    _rendering.add(key);
    final (lo, hi) = _range;
    try {
      final img = await renderArcImage(
        data: data,
        lo: lo,
        hi: hi,
        stage: _stageSize,
        density: b,
        faint: faint,
      );
      _images[key] = img;
      if (mounted) setState(() {});
    } finally {
      _rendering.remove(key);
    }
  }

  void _onInteractionEnd() {
    final density = densityFor(_geometry.effectiveWidth(_scale));
    final band = bandFor(density);
    if (band != _renderedBand) {
      _renderedBand = band;
      _ensureImage(faint: false, band: band);
      if (_selected != null) _ensureImage(faint: true, band: band);
    }
  }

  void _initView(Size viewport) {
    _fitScale = viewport.width / _stageSize.width;
    final ty = (viewport.height - _stageSize.height * _fitScale) / 2;
    _homeMatrix = Matrix4.identity()
      ..translateByDouble(0.0, ty > 0 ? ty : 0.0, 0.0, 1.0)
      ..scaleByDouble(_fitScale, _fitScale, 1.0, 1.0);
    _transform.value = _homeMatrix.clone();
    _scale = _fitScale;
    _viewInitialized = true;
  }

  void _resetView() {
    if (WwMotion.reduced(context)) {
      _transform.value = _homeMatrix.clone();
      _onInteractionEnd();
      return;
    }
    _anim?.dispose();
    _anim = AnimationController(vsync: this, duration: WwMotion.push)
      ..addListener(() {
        _transform.value = _animTween!.evaluate(_anim!);
      })
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed) _onInteractionEnd();
      });
    _animTween = Matrix4Tween(
      begin: _transform.value.clone(),
      end: _homeMatrix.clone(),
    );
    _anim!.forward();
  }

  void _selectAt(Offset stagePos) {
    final data = _data!;
    final (lo, hi) = _range;
    final pos = _geometry.posForX(stagePos.dx);
    final ch = data.chapterAtPosition(pos);
    if (ch < lo || ch > hi) return;
    setState(() => _selected = ch);
    _ensureImage(faint: true);
  }

  void _submitSearch(String raw) {
    final data = _data;
    if (data == null) return;
    final ch = data.parseSearch(raw);
    if (ch == null) return;
    final (lo, hi) = _range;
    setState(() {
      if (ch < lo || ch > hi) _scope = 'all';
      _selected = ch;
    });
    _ensureImage(faint: true);
    _searchCtl.clear();
    FocusScope.of(context).unfocus();
  }

  void _setScope(String scope) {
    if (scope == _scope) return;
    for (final img in _images.values) {
      img.dispose();
    }
    _images.clear();
    _renderedBand = bandFor(densityFor(_geometry.effectiveWidth(_scale)));
    setState(() {
      _scope = scope;
      _selected = null;
    });
    _resetView();
    _ensureImage(faint: false);
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    return Scaffold(
      backgroundColor: WwColors.stage,
      body: SafeArea(
        child: Column(
          children: [
            _topBar(),
            if (data != null) _tools(data),
            Expanded(child: _stageArea(data)),
            if (data != null && _selected != null) _selectionStrip(data),
            if (data != null) _hint(),
          ],
        ),
      ),
    );
  }

  Widget _topBar() {
    return Container(
      constraints: const BoxConstraints(minHeight: WwSpace.topBarHeight),
      padding: const EdgeInsets.symmetric(horizontal: WwSpace.screenMargin),
      decoration: const BoxDecoration(
        color: WwColors.nav,
        border: Border(bottom: BorderSide(color: Color(0xFF26262F))),
      ),
      child: const Row(
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Woven Word', style: WwType.appTitle),
              Text('BIBLE CROSS REFERENCES', style: WwType.appSubtitle),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tools(BibleData data) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        WwSpace.screenMargin,
        8,
        WwSpace.screenMargin,
        8,
      ),
      child: Row(
        children: [
          Container(
            height: WwSpace.minTarget,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: WwColors.surfaceHigh,
              borderRadius: BorderRadius.circular(WwRadius.input),
              border: Border.all(color: WwColors.borderDark),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _scope,
                dropdownColor: WwColors.surfaceHigh,
                style: WwType.controlLabel,
                icon: const Icon(
                  Icons.keyboard_arrow_down,
                  color: WwColors.mutedOnDark,
                ),
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('Whole Bible')),
                  DropdownMenuItem(
                    value: 'ot',
                    child: Text('Old Testament'),
                  ),
                  DropdownMenuItem(
                    value: 'nt',
                    child: Text('New Testament'),
                  ),
                ],
                onChanged: (v) {
                  if (v != null) _setScope(v);
                },
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SizedBox(
              height: WwSpace.minTarget,
              child: TextField(
                controller: _searchCtl,
                style: WwType.controlLabel,
                textInputAction: TextInputAction.search,
                onSubmitted: _submitSearch,
                decoration: const InputDecoration(
                  hintText: 'Jump to a book or chapter: John 3, Psalms 23…',
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Reset view',
            onPressed: _resetView,
            icon: const Icon(Icons.zoom_out_map, color: WwColors.navInk),
            style: IconButton.styleFrom(
              backgroundColor: WwColors.surfaceHigh,
              side: const BorderSide(color: WwColors.borderDark),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(WwRadius.input),
              ),
              minimumSize: const Size(
                WwSpace.minTarget,
                WwSpace.minTarget,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stageArea(BibleData? data) {
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'The web could not be woven.',
              style: WwType.bodyOnDark,
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: _load,
              child: const Text(
                'Try again',
                style: TextStyle(color: WwColors.goldBright, fontSize: 14),
              ),
            ),
          ],
        ),
      );
    }
    if (data == null) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Woven Word',
              style: TextStyle(
                fontFamily: WwType.serif,
                fontFamilyFallback: WwType.serifFallback,
                fontSize: 24,
                color: WwColors.goldBright,
              ),
            ),
            SizedBox(height: 12),
            Text('Weaving 344,799 connections…', style: WwType.captionOnDark),
          ],
        ),
      );
    }
    final (lo, hi) = _range;
    final density = densityFor(_geometry.effectiveWidth(_scale));
    final baseImage = _images[_key(_selected != null, _renderedBand)] ??
        _images[_key(false, _renderedBand)];
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewport = Size(constraints.maxWidth, constraints.maxHeight);
        if (!_viewInitialized) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && !_viewInitialized) {
              setState(() => _initView(viewport));
            }
          });
        }
        return InteractiveViewer(
          transformationController: _transform,
          minScale: _viewInitialized ? _fitScale * 0.95 : 0.05,
          maxScale: 3.5,
          constrained: false,
          boundaryMargin: const EdgeInsets.all(120),
          onInteractionEnd: (_) => _onInteractionEnd(),
          child: SizedBox(
            width: _stageSize.width,
            height: _stageSize.height,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: (d) => _selectAt(d.localPosition),
              onDoubleTap: _resetView,
              child: Stack(
                children: [
                  if (baseImage != null)
                    RawImage(
                      image: baseImage,
                      width: _stageSize.width,
                      height: _stageSize.height,
                      fit: BoxFit.fill,
                    ),
                  Positioned.fill(
                    child: CustomPaint(
                      painter: ArcOverlayPainter(
                        data: data,
                        lo: lo,
                        hi: hi,
                        stage: _stageSize,
                        selected: _selected,
                        density: density,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _selectionStrip(BibleData data) {
    final ch = _selected!;
    final c = data.chapters[ch];
    return Container(
      decoration: const BoxDecoration(
        color: WwColors.surface,
        border: Border(top: BorderSide(color: WwColors.borderDarkSoft)),
      ),
      padding: const EdgeInsets.only(left: WwSpace.screenMargin),
      child: Row(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(data.chapterName(ch), style: WwType.selectionTitle),
                  const SizedBox(height: 2),
                  Text(
                    '${c.v} verses · ${data.chapterConnCount[ch]} connections woven from this chapter',
                    style: WwType.captionOnDark,
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            tooltip: 'Clear selection',
            onPressed: () => setState(() => _selected = null),
            icon: const Icon(Icons.close, color: WwColors.navInk),
            constraints: const BoxConstraints(
              minWidth: WwSpace.minTarget,
              minHeight: WwSpace.minTarget,
            ),
          ),
        ],
      ),
    );
  }

  Widget _hint() {
    return const Padding(
      padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Text(
        'Tap any chapter bar to see its connections. Pinch to zoom, drag to explore.',
        style: WwType.hint,
        textAlign: TextAlign.center,
      ),
    );
  }
}
