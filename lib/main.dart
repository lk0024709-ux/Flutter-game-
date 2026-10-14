import 'package:material_ui/material_ui.dart';

import 'screens/forge_screen.dart';
import 'state/game_state.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final state = await GameState.load();
  runApp(BattleOfSwordMasterApp(state: state));
}

class BattleOfSwordMasterApp extends StatelessWidget {
  const BattleOfSwordMasterApp({super.key, required this.state});

  final GameState state;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Battle of Sword Master',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: ForgeScreen(state: state),
    );
  }
}
