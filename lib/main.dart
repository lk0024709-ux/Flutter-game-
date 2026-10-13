import 'package:flutter/material.dart';
import 'game/forge_state.dart';
import 'game/store_state.dart';
import 'theme/app_theme.dart';
import 'ui/home_screen.dart';
Future<void> main() async { WidgetsFlutterBinding.ensureInitialized(); await Future.wait([ForgeState.instance.load(), StoreState.instance.load()]); runApp(const BladeBrawlApp()); }
class BladeBrawlApp extends StatelessWidget { const BladeBrawlApp({super.key}); @override Widget build(BuildContext context)=>MaterialApp(title:'Blade Brawl: Rannbhoomi',debugShowCheckedModeBanner:false,theme:AppTheme.light,home:const HomeScreen()); }
