import 'package:flutter_test/flutter_test.dart';

import 'package:luxefeast_shop/main.dart';

void main() {
  testWidgets('LuxFeast Shop app renders', (WidgetTester tester) async {
    await tester.pumpWidget(const LuxFeastShopApp());
    expect(find.byType(LuxFeastShopApp), findsOneWidget);
  });
}
