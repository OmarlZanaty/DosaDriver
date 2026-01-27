import 'package:flutter_test/flutter_test.dart';
// Use relative path instead of package:dosadriver
import '../lib/main.dart';

void main() {
  testWidgets('App loads smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    expect(find.byType(MyApp), findsOneWidget);
  });
}
