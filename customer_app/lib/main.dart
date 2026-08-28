import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'services/popup_notifier.dart';
import 'screens/home_screen.dart';
import 'services/session.dart';
import 'services/auth_api.dart';
import 'services/cart_service.dart';

void main() {
  runApp(const LuxFeastApp());
}

class LuxFeastApp extends StatelessWidget {
  const LuxFeastApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nature Fete — Customer',
      debugShowCheckedModeBanner: false,
      theme: LuxTheme.theme,
      darkTheme: LuxTheme.theme,
      themeMode: ThemeMode.light,
      navigatorKey: PopupNotifier.navigatorKey,
      home: const AppGate(),
    );
  }
}

/// LuxFeast is browse-first: the menu shows immediately, no account needed.
/// A stored session (if any) is restored quietly in the background —
/// signing in is only ever required at checkout.
class AppGate extends StatefulWidget {
  const AppGate({super.key});

  @override
  State<AppGate> createState() => _AppGateState();
}

class _AppGateState extends State<AppGate> {
  bool checking = true;

  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    await Future.wait([
      Session.load(),
      CartService.instance.load(), // cart survives restarts (guests included)
    ]);
    if (Session.isLoggedIn) {
      final fresh = await AuthApi.me(Session.token!);
      if (fresh != null) {
        await Session.save(Session.token!, fresh);
      } else {
        await Session.clear(); // stale token → continue as guest
      }
    }
    if (mounted) setState(() => checking = false);
  }

  @override
  Widget build(BuildContext context) {
    if (checking) {
      return const Scaffold(
        backgroundColor: LuxTheme.deepBlack,
        body: Center(child: CircularProgressIndicator(color: LuxTheme.gold)),
      );
    }
    return const CustomerHomeScreen();
  }
}
