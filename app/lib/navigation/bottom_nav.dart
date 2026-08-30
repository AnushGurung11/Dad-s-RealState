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
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: const BoxDecoration(
            color: Color(0xF509090B), // rgba(9,9,11,0.96)
            border: Border(top: BorderSide(color: appBorder, width: 1)),
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
                      icon: const AppIconWidget(AppIcon.grid, size: 22, color: appText3),
                      selectedIcon: const AppIconWidget(AppIcon.grid, size: 22, color: appAccent),
                      label: 'Overview',
                    ),
                    NavigationDestination(
                      icon: const AppIconWidget(AppIcon.building, size: 22, color: appText3),
                      selectedIcon: const AppIconWidget(AppIcon.building, size: 22, color: appAccent),
                      label: 'Flats',
                    ),
                    NavigationDestination(
                      icon: const AppIconWidget(AppIcon.people, size: 22, color: appText3),
                      selectedIcon: const AppIconWidget(AppIcon.people, size: 22, color: appAccent),
                      label: 'Tenants',
                    ),
                    NavigationDestination(
                      icon: const AppIconWidget(AppIcon.wallet, size: 22, color: appText3),
                      selectedIcon: const AppIconWidget(AppIcon.wallet, size: 22, color: appAccent),
                      label: 'Finance',
                    ),
                    NavigationDestination(
                      icon: const AppIconWidget(AppIcon.dots, size: 22, color: appText3),
                      selectedIcon: const AppIconWidget(AppIcon.dots, size: 22, color: appAccent),
                      label: 'More',
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Container(
                  width: 24,
                  height: 4,
                  decoration: BoxDecoration(color: appBorder, borderRadius: BorderRadius.circular(2)),
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
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: appSurface1,
      barrierColor: const Color(0xA6000000), // rgba(0,0,0,0.65)
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        side: BorderSide(color: appBorderMd),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(width: 36, height: 3, decoration: BoxDecoration(color: appBorderMd, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 12),
            ListTile(
              key: const Key('more_settings'),
              leading: Container(width: 32, height: 32, decoration: BoxDecoration(color: appAccentDim, borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.settings_outlined, size: 18, color: appAccent)),
              title: const Text('Settings', style: TextStyle(fontSize: 15, color: appText1)),
              onTap: () {
                Navigator.pop(ctx);
                onSelect('/settings');
              },
            ),
            ListTile(
              key: const Key('more_archived_tenants'),
              leading: Container(width: 32, height: 32, decoration: BoxDecoration(color: appAccentDim, borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.person_off_outlined, size: 18, color: appAccent)),
              title: const Text('Archived Tenants', style: TextStyle(fontSize: 15, color: appText1)),
              onTap: () {
                Navigator.pop(ctx);
                onSelect('/archive/tenants');
              },
            ),
            ListTile(
              key: const Key('more_archive_flats'),
              leading: Container(width: 32, height: 32, decoration: BoxDecoration(color: appAccentDim, borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.apartment_outlined, size: 18, color: appAccent)),
              title: const Text('Archive Flats', style: TextStyle(fontSize: 15, color: appText1)),
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
