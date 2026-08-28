import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'screens/home_screen.dart';
import 'screens/auth_screen.dart';
import 'services/session.dart';
import 'services/auth_api.dart';

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
      home: const AuthGate(),
    );
  }
}

/// Restores a stored session (validating the JWT) or shows the auth flow.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool checking = true;
  bool authed = false;

  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    await Session.load();
    if (Session.isLoggedIn) {
      final fresh = await AuthApi.me(Session.token!);
      if (fresh != null) {
        await Session.save(Session.token!, fresh);
        setState(() { authed = true; checking = false; });
        return;
      }
      await Session.clear();
    }
    setState(() => checking = false);
  }

  @override
  Widget build(BuildContext context) {
    if (checking) {
      return const Scaffold(
        backgroundColor: LuxTheme.deepBlack,
        body: Center(child: CircularProgressIndicator(color: LuxTheme.gold)),
      );
    }
    if (!authed) {
      return AuthScreen(
        role: 'customer',
        title: 'Premium Dining • Delivered',
        onAuthed: () => setState(() => authed = true),
      );
    }
    return const CustomerHomeScreen();
  }
}
