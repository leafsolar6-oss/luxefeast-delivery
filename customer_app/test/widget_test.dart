import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:luxefeast_customer/main.dart';
import 'package:luxefeast_customer/screens/home_screen.dart';
import 'package:luxefeast_customer/screens/auth_screen.dart';

void main() {
  testWidgets('LuxFeast customer app renders', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const LuxFeastApp());
    expect(find.byType(LuxFeastApp), findsOneWidget);
  });

  testWidgets('opens straight to browsing — no login wall',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const LuxFeastApp());

    // Session/cart restore + first shop load attempt.
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));

    // Guest lands on the restaurant list, never on the auth screen.
    expect(find.byType(CustomerHomeScreen), findsOneWidget);
    expect(find.byType(AuthScreen), findsNothing);
    expect(find.text('Featured Restaurants'), findsOneWidget);
  });
}
