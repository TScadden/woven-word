import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

/// Selection-mode long-press entry (board run 10 fix round,
/// founder verification Oct 22, 2026: "holding down to select
/// is a little difficult — it doesn't always select").
///
/// Root cause: the entry relied on InkWell's stock long-press
/// recognizer — a 500 ms deadline with an 18 px pre-acceptance
/// slop. Half a second is longer than a natural hold, so the
/// founder released presses that had not fired yet; drift past
/// 18 px in that window let the pager's or the page's own drag
/// claim the arena and kill the press outright. And when a
/// press DID fire, nothing visibly changed — the mode swaps
/// plain text for an identical-looking SelectableText — so a
/// successful press read as a failed one.
///
/// The fix: this detector registers its own recognizer for the
/// verse block in the same arena — a 350 ms deadline (inside a
/// natural hold, with far less time to drift) and 42 px of
/// drift tolerated before acceptance — plus immediate feedback
/// at the call sites (a haptic tick and the block's outline for
/// as long as the mode is open). Selection remains a MODE:
/// outside it every shipped gesture is untouched (LESSONS #39).
///
/// Considered and rejected in this round: raising the drags'
/// touch slop alongside (via MediaQuery gestureSettings). The
/// shipped suite caught it — R-T10's in-page scroll drag is
/// swallowed whole when a drag recognizer accepts late, because
/// the pending offset is discarded at acceptance; a drag slop
/// above the stock 18 px measurably deadens the first part of
/// every scroll. The shorter deadline is what actually closes
/// the steal window: a movement that crosses 18 px inside
/// 350 ms IS a swipe, and the page is right to take it.
const kSelectionLongPressTimeout = Duration(milliseconds: 350);
const kSelectionLongPressSlopPx = 42.0;

/// The long-press recognizer for entering selection mode: the
/// stock recognizer with a shorter deadline and a widened
/// pre-acceptance drift tolerance.
class SelectionLongPressRecognizer extends LongPressGestureRecognizer {
  SelectionLongPressRecognizer() : super(duration: kSelectionLongPressTimeout);

  @override
  double? get preAcceptSlopTolerance => kSelectionLongPressSlopPx;
}

/// Wraps one verse block; fires [onLongPress] when the block is
/// held (see the note above). The block's own tap handling is
/// unaffected — this detector registers only the long-press.
///
/// [enabled] exists for the mode itself: while the verse is IN
/// selection mode the detector registers nothing, so a
/// long-press inside the mode belongs entirely to the
/// SelectableText (it takes a word) and the entry recognizer
/// cannot steal it.
class VerseLongPressDetector extends StatelessWidget {
  const VerseLongPressDetector({
    super.key,
    required this.child,
    required this.onLongPress,
    this.enabled = true,
  });

  final Widget child;
  final VoidCallback onLongPress;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return RawGestureDetector(
      behavior: HitTestBehavior.translucent,
      gestures: enabled
          ? <Type, GestureRecognizerFactory>{
              SelectionLongPressRecognizer:
                  GestureRecognizerFactoryWithHandlers<
                    SelectionLongPressRecognizer
                  >(() => SelectionLongPressRecognizer(), (instance) {
                    instance.onLongPress = onLongPress;
                  }),
            }
          : const <Type, GestureRecognizerFactory>{},
      child: child,
    );
  }
}
