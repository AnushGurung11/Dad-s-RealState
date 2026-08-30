import 'dart:ui';

import 'package:flutter/material.dart';

import '../icons/app_icons.dart';
import '../theme/app_theme.dart';

/// Bottom navigation for LUCKY — 5 destinations per patch section 1.
class LuckyBottomNav extends StatelessWidget {
  const LuckyBottomNav({
    super.key,
    required this.currentRoute,
    required this.onSelect,
  });

  final String currentRoute;
  final ValueChanged<String> onSelect;

  int _indexFor(String route) {
    if (route == '/' || route == '/dashboard') {
      return 0;
    }
    if (route.startsWith('/flats')) {
      return 1;
    }
    if (route.startsWith('/tenants')) {
      return 2;
    }
    if (route.startsWith('/finance') ||
        route.startsWith('/payments') ||
        route.startsWith('/history') ||
        route.startsWith('/expenses') ||
        route.startsWith('/report')) {
      return 3;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final index = _indexFor(currentRoute);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final navBg = theme.navigationBarTheme.backgroundColor ?? (isDark ? const Color(0xF509090B) : appLightNavBg);
    final borderColor = theme.dividerTheme.color ?? (isDark ? appBorder : appLightBorder);
    final inactiveColor = isDark ? appText3 : appLightText3;
    final activeColor = isDark ? appAccent : appLightAccent;
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: navBg,
            border: Border(top: BorderSide(color: borderColor, width: 1)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                NavigationBar(
                  backgroundColor: Colors.transparent,
                  surfaceTintColor: Colors.transparent,
                  elevation: 0,
                  height: 64,
                  selectedIndex: index > 4 ? 0 : index,
                  onDestinationSelected: (i) {
                    if (i == 4) {
                      _showMoreSheet(context);
                      return;
                    }
                    switch (i) {
                      case 0:
                        onSelect('/');
                        break;
                      case 1:
                        onSelect('/flats');
                        break;
                      case 2:
                        onSelect('/tenants');
                        break;
                      case 3:
                        onSelect('/finance');
                        break;
                    }
                  },
                  destinations: [
                    NavigationDestination(
                      icon: AppIconWidget(AppIcon.grid, size: 22, color: inactiveColor),
                      selectedIcon: AppIconWidget(AppIcon.grid, size: 22, color: activeColor),
                      label: 'Overview',
                    ),
                    NavigationDestination(
                      icon: AppIconWidget(AppIcon.building, size: 22, color: inactiveColor),
                      selectedIcon: AppIconWidget(AppIcon.building, size: 22, color: activeColor),
                      label: 'Flats',
                    ),
                    NavigationDestination(
                      icon: AppIconWidget(AppIcon.people, size: 22, color: inactiveColor),
                      selectedIcon: AppIconWidget(AppIcon.people, size: 22, color: activeColor),
                      label: 'Tenants',
                    ),
                    NavigationDestination(
                      icon: AppIconWidget(AppIcon.wallet, size: 22, color: inactiveColor),
                      selectedIcon: AppIconWidget(AppIcon.wallet, size: 22, color: activeColor),
                      label: 'Finance',
                    ),
                    NavigationDestination(
                      icon: AppIconWidget(AppIcon.dots, size: 22, color: inactiveColor),
                      selectedIcon: AppIconWidget(AppIcon.dots, size: 22, color: activeColor),
                      label: 'More',
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Container(
                  width: 24,
                  height: 4,
                  decoration: BoxDecoration(color: borderColor, borderRadius: BorderRadius.circular(2)),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showMoreSheet(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surface1 = isDark ? appSurface1 : appLightSurface2;
    final borderMd = isDark ? appBorderMd : appLightBorderMd;
    final accent = isDark ? appAccent : appLightAccent;
    final accentDim = isDark ? appAccentDim : appLightAccentDim;
    final text1 = isDark ? appText1 : appLightText1;
    final sheetBorder = isDark ? appBorderMd : appLightBorderMd;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: surface1,
      barrierColor: const Color(0xA6000000),
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        side: BorderSide(color: sheetBorder),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(width: 36, height: 3, decoration: BoxDecoration(color: borderMd, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 12),
            ListTile(
              key: const Key('more_settings'),
              leading: Container(width: 32, height: 32, decoration: BoxDecoration(color: accentDim, borderRadius: BorderRadius.circular(12)), child: Icon(Icons.settings_outlined, size: 18, color: accent)),
              title: Text('Settings', style: TextStyle(fontSize: 15, color: text1)),
              onTap: () {
                Navigator.pop(ctx);
                onSelect('/settings');
              },
            ),
            ListTile(
              key: const Key('more_archived_tenants'),
              leading: Container(width: 32, height: 32, decoration: BoxDecoration(color: accentDim, borderRadius: BorderRadius.circular(12)), child: Icon(Icons.person_off_outlined, size: 18, color: accent)),
              title: Text('Archived Tenants', style: TextStyle(fontSize: 15, color: text1)),
              onTap: () {
                Navigator.pop(ctx);
                onSelect('/archive/tenants');
              },
            ),
            ListTile(
              key: const Key('more_archive_flats'),
              leading: Container(width: 32, height: 32, decoration: BoxDecoration(color: accentDim, borderRadius: BorderRadius.circular(12)), child: Icon(Icons.apartment_outlined, size: 18, color: accent)),
              title: Text('Archive Flats', style: TextStyle(fontSize: 15, color: text1)),
              onTap: () {
                Navigator.pop(ctx);
                onSelect('/archive/flats');
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
