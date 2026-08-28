import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'shop_dashboard_screen.dart';
import 'menu_manager_screen.dart';
import 'earnings_screen.dart';
import 'settings_screen.dart';

/// Main shop navigation — Orders / Menu / Earnings / Settings.
/// IndexedStack keeps every tab's state (and live socket) alive.
class ShopHomeShell extends StatefulWidget {
  const ShopHomeShell({super.key});

  @override
  State<ShopHomeShell> createState() => _ShopHomeShellState();
}

class _ShopHomeShellState extends State<ShopHomeShell> {
  int _index = 0;

  static const _tabs = [
    ShopDashboardScreen(),
    MenuManagerScreen(),
    EarningsScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LuxTheme.deepBlack,
      body: IndexedStack(index: _index, children: _tabs),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: LuxTheme.surface,
          border: Border(top: BorderSide(color: LuxTheme.gold.withOpacity(0.15))),
        ),
        child: NavigationBarTheme(
          data: NavigationBarThemeData(
            backgroundColor: Colors.transparent,
            indicatorColor: LuxTheme.gold.withOpacity(0.15),
            labelTextStyle: WidgetStatePropertyAll(TextStyle(
                fontSize: 11, fontWeight: FontWeight.w600, color: LuxTheme.textSecondary)),
          ),
          child: NavigationBar(
            height: 68,
            selectedIndex: _index,
            onDestinationSelected: (i) => setState(() => _index = i),
            destinations: const [
              NavigationDestination(
                  icon: Icon(Icons.receipt_long_outlined, color: LuxTheme.textSecondary),
                  selectedIcon: Icon(Icons.receipt_long_rounded, color: LuxTheme.gold),
                  label: 'Orders'),
              NavigationDestination(
                  icon: Icon(Icons.restaurant_menu_outlined, color: LuxTheme.textSecondary),
                  selectedIcon: Icon(Icons.restaurant_menu_rounded, color: LuxTheme.gold),
                  label: 'Menu'),
              NavigationDestination(
                  icon: Icon(Icons.payments_outlined, color: LuxTheme.textSecondary),
                  selectedIcon: Icon(Icons.payments_rounded, color: LuxTheme.gold),
                  label: 'Earnings'),
              NavigationDestination(
                  icon: Icon(Icons.settings_outlined, color: LuxTheme.textSecondary),
                  selectedIcon: Icon(Icons.settings_rounded, color: LuxTheme.gold),
                  label: 'Settings'),
            ],
          ),
        ),
      ),
    );
  }
}
