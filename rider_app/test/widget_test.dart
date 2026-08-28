import 'package:flutter_test/flutter_test.dart';

import 'package:luxefeast_rider/main.dart';

void main() {
  testWidgets('LuxFeast rider app renders', (WidgetTester tester) async {
    await tester.pumpWidget(const LuxFeastRiderApp());
    expect(find.byType(LuxFeastRiderApp), findsOneWidget);
  });
}
