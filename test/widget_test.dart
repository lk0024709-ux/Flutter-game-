import 'package:flutter_test/flutter_test.dart';
import 'package:blade_brawl/main.dart';
void main(){testWidgets('Forge home renders',(tester)async{await tester.pumpWidget(const BladeBrawlApp());await tester.pump(const Duration(milliseconds:100));expect(find.text('The Forge Yard'),findsOneWidget);});}
