import 'package:flutter_test/flutter_test.dart';
import 'package:waterleak/main.dart';

void main() {
  testWidgets('App builds', (tester) async {
    await tester.pumpWidget(MyApp());
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('WELCOME TO WATERLEAK!'), findsOneWidget);
  });
}
