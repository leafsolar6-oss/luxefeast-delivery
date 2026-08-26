import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'screens/rider_dashboard_screen.dart';

void main() => runApp(const LuxFeastRiderApp());

class LuxFeastRiderApp extends StatelessWidget {
  const LuxFeastRiderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LuxFeast — Rider',
      debugShowCheckedModeBanner: false,
      theme: LuxTheme.dark,
      darkTheme: LuxTheme.dark,
      themeMode: ThemeMode.dark,
      home: const RiderDashboardScreen(),
    );
  }
}
