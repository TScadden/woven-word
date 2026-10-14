import 'package:flutter/material.dart';

import 'screens/arc_web_screen.dart';
import 'theme/ww_theme.dart';

void main() {
  runApp(const WovenWordApp());
}

class WovenWordApp extends StatelessWidget {
  const WovenWordApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Woven Word',
      debugShowCheckedModeBanner: false,
      theme: wwTheme(),
      home: const ArcWebScreen(),
    );
  }
}
