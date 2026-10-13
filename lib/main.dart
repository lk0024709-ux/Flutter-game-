import 'package:flutter/material.dart';

import 'game/forge_state.dart';
import 'game/store_state.dart';
import 'theme/app_theme.dart';
import 'ui/home_screen.dart';

/// Entry point.
///
/// Loads both singletons from `shared_preferences` before the first frame so
/// the home screen never shows a "level 1 / 0 coins" flash, then starts the
/// idle forge engine.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Future.wait<void>(<Future<void>>[
    StoreState.instance.load(),
    ForgeState.instance.load(),
  ]);
  ForgeState.instance.startEngine();
  runApp(const BladeBrawlApp());
}

/// The application shell.
///
/// The whole app is light and warm; the Chimera Trials are the only place that
/// switches to the dark palette, which makes entering elite mode feel like
/// stepping into a different arena.
class BladeBrawlApp extends StatelessWidget {
  const BladeBrawlApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Blade Brawl: Rannbhoomi',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.light,
      home: const HomeScreen(),
    );
  }
}
