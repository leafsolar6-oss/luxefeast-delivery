import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'services/popup_notifier.dart';
import 'screens/rider_dashboard_screen.dart';
import 'screens/auth_screen.dart';
import 'services/session.dart';
import 'services/auth_api.dart';
import 'services/push_service.dart';

void main() => runApp(const LuxFeastRiderApp());

class LuxFeastRiderApp extends StatelessWidget {
  const LuxFeastRiderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nature Fete — Rider',
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
        PushService.init();
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
        role: 'rider',
        title: 'Rider Partner • Earn in ₦',
        onAuthed: () { PushService.init(); setState(() => authed = true); },
      );
    }
    return const RiderDashboardScreen();
  }
}
