import 'package:flutter/material.dart';

import '../theme/ww_theme.dart';

/// Home screen. Blank for now by the founder's direction (Oct 13, 2026):
/// the opening animation lands here first; the book/chapter list redesign
/// is built into this screen next.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: WwColors.nav,
      body: SizedBox.expand(),
    );
  }
}
