import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:blade_brawl/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets('Forge home renders', (tester) async {
    await tester.pumpWidget(const BladeBrawlApp());
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('The Forge Yard'), findsOneWidget);
  });
}
