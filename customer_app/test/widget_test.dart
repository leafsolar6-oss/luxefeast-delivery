import 'package:flutter_test/flutter_test.dart';

import 'package:luxefeast_customer/main.dart';

void main() {
  testWidgets('LuxFeast customer app renders', (WidgetTester tester) async {
    await tester.pumpWidget(const LuxFeastApp());
    expect(find.byType(LuxFeastApp), findsOneWidget);
  });
}
