#!/bin/bash
echo "Making LuxFeast fully Nigerian..."

# Update customer theme with Nigerian green accent
sed -i 's/Color(0xFFD4AF37)/Color(0xFFD4AF37)/g' /home/user/customer_app/lib/theme/app_theme.dart

# Add Nigerian flag colors to theme
sed -i 's/static const Color gold = Color(0xFFD4AF37);/static const Color gold = Color(0xFFD4AF37);\n  static const Color naijaGreen = Color(0xFF008751);\n  static const Color naijaWhite = Color(0xFFFFFFFF);/g' /home/user/customer_app/lib/theme/app_theme.dart

echo "Theme updated with Nigerian green (#008751)"
