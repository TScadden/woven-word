import 'package:flutter/material.dart';

import '../data/bible_data.dart';
import '../data/screen_state.dart';
import '../theme/ww_theme.dart';

/// The Screens tab root (§6.1): held places made visible — one row
/// per screen, in creation order, with the New Screen button and
/// the binding cap of 5 (§0.1/§6.3).
class ScreensTab extends StatelessWidget {
  const ScreensTab({
    super.key,
    required this.data,
    required this.screens,
    required this.activeIndex,
    required this.onRowTap,
    required this.onClose,
    required this.onNew,
  });

  final BibleData? data;
  final List<ReadingScreen> screens;
  final int activeIndex;
  final void Function(int index) onRowTap;
  final void Function(int index) onClose;
  final VoidCallback onNew;

  @override
  Widget build(BuildContext context) {
    final atCap = screens.length >= wwMaxScreens;
    return Scaffold(
      backgroundColor: WwColors.stage,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              constraints: const BoxConstraints(
                minHeight: WwSpace.topBarHeight,
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: WwSpace.screenMargin,
              ),
              decoration: const BoxDecoration(
                color: WwColors.nav,
                border: Border(
                  bottom: BorderSide(color: WwColors.borderDarkSoft),
                ),
              ),
              child: const Row(
                children: [Text('Screens', style: WwType.screenTitle)],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                children: [
                  const Text(
                    'Places you are holding. Screens live on this device only.',
                    style: WwType.captionOnDark,
                  ),
                  const SizedBox(height: 16),
                  for (var i = 0; i < screens.length; i++) ...[
                    _row(i),
                    const SizedBox(height: 8),
                  ],
                  ElevatedButton(
                    onPressed: atCap ? null : onNew,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: atCap
                          ? WwColors.surface
                          : WwColors.goldBright,
                      foregroundColor: atCap
                          ? WwColors.mutedOnDark
                          : WwColors.onGold,
                      minimumSize: const Size.fromHeight(WwSpace.minTarget),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(WwRadius.chip),
                      ),
                    ),
                    child: Text(
                      'New screen',
                      style: atCap
                          ? WwType.buttonLabel.copyWith(
                              color: WwColors.mutedOnDark,
                            )
                          : WwType.goldButtonLabel,
                    ),
                  ),
                  if (atCap) ...[
                    const SizedBox(height: 8),
                    const Text(
                      'Five places is the limit. Close one to open another.',
                      style: WwType.captionOnDark,
                    ),
                  ],
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(int i) {
    final screen = screens[i];
    final isActive = i == activeIndex;
    final d = data;
    final String title;
    final String subtitle;
    if (!screen.bound) {
      title = 'New screen';
      subtitle = 'Choose a chapter in Library';
    } else if (d != null) {
      title = d.chapterName(screen.globalChapter);
      subtitle = screen.anchorVerse != null
          ? 'verse ${screen.anchorVerse}'
          : 'at chapter start';
    } else {
      title = 'Chapter ${screen.globalChapter + 1}';
      subtitle = screen.anchorVerse != null
          ? 'verse ${screen.anchorVerse}'
          : 'at chapter start';
    }
    return Material(
      color: WwColors.surface,
      borderRadius: BorderRadius.circular(WwRadius.row),
      child: InkWell(
        borderRadius: BorderRadius.circular(WwRadius.row),
        onTap: () => onRowTap(i),
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
                    if (isActive) ...[
                      const SizedBox(height: 2),
                      const Text('Active', style: WwType.activeCaption),
                    ],
                  ],
                ),
              ),
              if (isActive)
                const Icon(
                  Icons.check_circle,
                  size: 20,
                  color: WwColors.goldBright,
                ),
              if (screens.length > 1)
                IconButton(
                  tooltip: 'Close screen',
                  onPressed: () => onClose(i),
                  icon: const Icon(
                    Icons.close,
                    size: 20,
                    color: WwColors.navInk,
                  ),
                  constraints: const BoxConstraints(
                    minWidth: WwSpace.minTarget,
                    minHeight: WwSpace.minTarget,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
