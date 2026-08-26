import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'screens/shop_dashboard_screen.dart';

void main() => runApp(const LuxFeastShopApp());

class LuxFeastShopApp extends StatelessWidget {
  const LuxFeastShopApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LuxFeast — Shop',
      debugShowCheckedModeBanner: false,
      theme: LuxTheme.dark,
      darkTheme: LuxTheme.dark,
      themeMode: ThemeMode.dark,
      home: const ShopDashboardScreen(),
    );
  }
}
