import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const LuxFeastApp());
}

class LuxFeastApp extends StatelessWidget {
  const LuxFeastApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LuxFeast — Customer',
      debugShowCheckedModeBanner: false,
      theme: LuxTheme.dark,
      darkTheme: LuxTheme.dark,
      themeMode: ThemeMode.dark,
      home: const CustomerHomeScreen(),
    );
  }
}
