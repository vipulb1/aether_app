import 'package:flutter_test/flutter_test.dart';
import 'package:aether_app/main.dart';

void main() {
  testWidgets('App renders without errors', (WidgetTester tester) async {
    await tester.pumpWidget(const AetherApp());
    expect(find.text('Aether'), findsOneWidget);
  });
}
