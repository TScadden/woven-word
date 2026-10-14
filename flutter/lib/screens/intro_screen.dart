import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/ww_theme.dart';
import 'shell_screen.dart';

/// First-run gate (ratified decision, Oct 14, 2026 — option c).
///
/// Every launch after the first goes straight to the shell
/// ([WwShell], board run 7 part B §1: "Begin reading" enters the
/// shell at the Home tab); only the
/// first run sees the static [IntroScreen]. While the persisted flag is
/// still loading, a plain black stage renders — visually continuous with
/// the system splash, no spinner, no chrome.
class IntroGate extends StatefulWidget {
  const IntroGate({super.key});

  static const introSeenKey = 'ww_intro_seen';

  @override
  State<IntroGate> createState() => _IntroGateState();
}

class _IntroGateState extends State<IntroGate> {
  bool? _introSeen;

  @override
  void initState() {
    super.initState();
    _loadIntroSeen();
  }

  Future<void> _loadIntroSeen() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => _introSeen = prefs.getBool(IntroGate.introSeenKey) ?? false);
  }

  @override
  Widget build(BuildContext context) {
    final seen = _introSeen;
    if (seen == null) {
      return const Scaffold(
        backgroundColor: WwColors.stage,
        body: SizedBox.expand(),
      );
    }
    if (seen) return const WwShell();
    return const IntroScreen();
  }
}

/// Static first-run intro: black stage, app icon, wordmark, one plain
/// line about the cross references, and a Begin reading button.
/// User-paced — no animation of its own, nothing auto-advances.
class IntroScreen extends StatelessWidget {
  const IntroScreen({super.key});

  Future<void> _beginReading(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(IntroGate.introSeenKey, true);
    if (!context.mounted) return;
    await Navigator.of(context)
        .pushReplacement(WwPageRoute(builder: (_) => const WwShell()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WwColors.stage,
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: WwSpace.screenMargin),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Align(
              alignment: Alignment.center,
              child: Image(
                image: AssetImage('assets/app_icon.png'),
                width: 120,
                height: 120,
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'Woven Word',
              style: WwType.wordmark,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            const Text(
              '344,799 cross references, woven chapter to chapter.',
              style: WwType.bodyOnDark,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () => _beginReading(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: WwColors.goldBright,
                foregroundColor: WwColors.onGold,
                minimumSize: const Size.fromHeight(WwSpace.minTarget),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(WwRadius.chip),
                ),
              ),
              child: const Text('Begin reading', style: WwType.goldButtonLabel),
            ),
          ],
        ),
      ),
    );
  }
}
