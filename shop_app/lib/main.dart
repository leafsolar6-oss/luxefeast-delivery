import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'services/popup_notifier.dart';
import 'screens/shop_home_shell.dart';
import 'screens/auth_screen.dart';
import 'services/session.dart';
import 'services/auth_api.dart';

void main() => runApp(const LuxFeastShopApp());

class LuxFeastShopApp extends StatelessWidget {
  const LuxFeastShopApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nature Fete — Shop',
      debugShowCheckedModeBanner: false,
      theme: LuxTheme.theme,
      darkTheme: LuxTheme.theme,
      themeMode: ThemeMode.light,
      navigatorKey: PopupNotifier.navigatorKey,
      home: const AuthGate(),
    );
  }
}

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
        role: 'shop',
        title: 'Restaurant Partner Dashboard',
        onAuthed: () => setState(() => authed = true),
      );
    }
    return const ShopHomeShell();
  }
}
