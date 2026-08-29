import 'package:flutter/material.dart';

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
    // More is always index 4 but not a real route — it's a sheet.
    return NavigationBar(
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
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.dashboard_outlined),
          selectedIcon: Icon(Icons.dashboard),
          label: 'Dashboard',
        ),
        NavigationDestination(
          icon: Icon(Icons.apartment_outlined),
          selectedIcon: Icon(Icons.apartment),
          label: 'Flats',
        ),
        NavigationDestination(
          icon: Icon(Icons.group_outlined),
          selectedIcon: Icon(Icons.group),
          label: 'Tenants',
        ),
        NavigationDestination(
          icon: Icon(Icons.account_balance_wallet_outlined),
          selectedIcon: Icon(Icons.account_balance_wallet),
          label: 'Finance',
        ),
        NavigationDestination(
          icon: Icon(Icons.more_horiz),
          selectedIcon: Icon(Icons.more_horiz),
          label: 'More',
        ),
      ],
    );
  }

  void _showMoreSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              key: const Key('more_settings'),
              leading: const Icon(Icons.settings_outlined),
              title: const Text('Settings'),
              onTap: () {
                Navigator.pop(ctx);
                onSelect('/settings');
              },
            ),
            ListTile(
              key: const Key('more_archived_tenants'),
              leading: const Icon(Icons.person_off_outlined),
              title: const Text('Archived Tenants'),
              onTap: () {
                Navigator.pop(ctx);
                onSelect('/archive/tenants');
              },
            ),
            ListTile(
              key: const Key('more_archive_flats'),
              leading: const Icon(Icons.apartment_outlined),
              title: const Text('Archive Flats'),
              onTap: () {
                Navigator.pop(ctx);
                onSelect('/archive/flats');
              },
            ),
          ],
        ),
      ),
    );
  }
}
