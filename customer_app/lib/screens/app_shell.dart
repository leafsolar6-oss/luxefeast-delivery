import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../services/cart_service.dart';
import 'home_screen.dart';
import 'orders_screen.dart';
import 'account_screen.dart';

/// Chowdeck-style app shell — bottom navigation: Home · Orders · Account.
/// IndexedStack keeps state (and the live order socket) alive across tabs.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LuxTheme.bg,
      body: IndexedStack(
        index: _index,
        children: const [CustomerHomeScreen(), OrdersScreen(), AccountScreen()],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: LuxTheme.surface, width: 1)),
        ),
        child: ListenableBuilder(
          listenable: CartService.instance,
          builder: (context, _) => NavigationBarTheme(
            data: NavigationBarThemeData(
              backgroundColor: Colors.white,
              indicatorColor: LuxTheme.primary.withOpacity(0.12),
              labelTextStyle: WidgetStatePropertyAll(
                GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: LuxTheme.textSecondary),
              ),
            ),
            child: NavigationBar(
              height: 66,
              selectedIndex: _index,
              onDestinationSelected: (i) => setState(() => _index = i),
              destinations: [
                const NavigationDestination(
                    icon: Icon(Icons.storefront_outlined,
                        color: LuxTheme.textSecondary),
                    selectedIcon:
                        Icon(Icons.storefront_rounded, color: LuxTheme.primary),
                    label: 'Home'),
                const NavigationDestination(
                    icon: Icon(Icons.receipt_long_outlined,
                        color: LuxTheme.textSecondary),
                    selectedIcon: Icon(Icons.receipt_long_rounded,
                        color: LuxTheme.primary),
                    label: 'Orders'),
                NavigationDestination(
                  icon: Icon(
                      _index == 2
                          ? Icons.person_rounded
                          : Icons.person_outline_rounded,
                      color: LuxTheme.textSecondary),
                  selectedIcon:
                      const Icon(Icons.person_rounded, color: LuxTheme.primary),
                  label: 'Account',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
