import 'package:flutter/material.dart';

import '../config.dart';
import 'routes.dart';

/// Left drawer replacing the old bottom navigation bar. Highlights the
/// currently active route and navigates via [onSelect].
class AppDrawer extends StatelessWidget {
  const AppDrawer({
    super.key,
    required this.currentRoute,
    required this.onSelect,
  });

  final String currentRoute;
  final ValueChanged<String> onSelect;

  void _go(BuildContext context, String route) {
    Navigator.pop(context);
    onSelect(route);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.home_work_outlined,
                  color: theme.colorScheme.onPrimaryContainer,
                  size: 36,
                ),
                const SizedBox(width: 12),
                Text(
                  AppConfig.appName,
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          _Tile(
            icon: Icons.dashboard_outlined,
            label: 'Dashboard',
            route: Routes.dashboard,
            currentRoute: currentRoute,
            onTap: () => _go(context, Routes.dashboard),
          ),
          _Tile(
            icon: Icons.apartment_outlined,
            label: 'Flats',
            route: Routes.flats,
            currentRoute: currentRoute,
            onTap: () => _go(context, Routes.flats),
          ),
          _Expandable(
            icon: Icons.group_outlined,
            label: 'Tenants',
            currentRoute: currentRoute,
            children: [
              _Tile(
                icon: Icons.groups_outlined,
                label: 'All tenants',
                route: Routes.tenants,
                currentRoute: currentRoute,
                onTap: () => _go(context, Routes.tenants),
              ),
              _Tile(
                icon: Icons.person_add_outlined,
                label: 'Add tenant',
                route: Routes.tenantsAdd,
                currentRoute: currentRoute,
                onTap: () => _go(context, Routes.tenantsAdd),
              ),
              _Tile(
                icon: Icons.link,
                label: 'Assign',
                route: Routes.tenantsAssign,
                currentRoute: currentRoute,
                onTap: () => _go(context, Routes.tenantsAssign),
              ),
            ],
          ),
          _Expandable(
            icon: Icons.payments_outlined,
            label: 'Payments',
            currentRoute: currentRoute,
            children: [
              _Tile(
                icon: Icons.description_outlined,
                label: 'Cheque Payment (Flat)',
                route: Routes.paymentsFlatLease,
                currentRoute: currentRoute,
                onTap: () => _go(context, Routes.paymentsFlatLease),
              ),
              _Tile(
                icon: Icons.person_outlined,
                label: 'Tenant Rent Payment',
                route: Routes.paymentsTenantRent,
                currentRoute: currentRoute,
                onTap: () => _go(context, Routes.paymentsTenantRent),
              ),
            ],
          ),
          _Expandable(
            icon: Icons.receipt_long_outlined,
            label: 'Payment History',
            currentRoute: currentRoute,
            children: [
              _Tile(
                icon: Icons.history,
                label: 'Flat Lease History',
                route: Routes.historyFlatLease,
                currentRoute: currentRoute,
                onTap: () => _go(context, Routes.historyFlatLease),
              ),
              _Tile(
                icon: Icons.history_edu,
                label: 'Tenant Rent History',
                route: Routes.historyTenantRent,
                currentRoute: currentRoute,
                onTap: () => _go(context, Routes.historyTenantRent),
              ),
            ],
          ),
          _Tile(
            icon: Icons.request_quote_outlined,
            label: 'Expenses',
            route: Routes.expenses,
            currentRoute: currentRoute,
            onTap: () => _go(context, Routes.expenses),
          ),
          _Expandable(
            icon: Icons.settings_outlined,
            label: 'Settings',
            currentRoute: currentRoute,
            children: [
              _Tile(
                icon: Icons.archive_outlined,
                label: 'Archive',
                route: Routes.settingsArchive,
                currentRoute: currentRoute,
                onTap: () => _go(context, Routes.settingsArchive),
              ),
            ],
          ),
          const Divider(),
          ListTile(
            enabled: false,
            leading: const Icon(Icons.assessment_outlined),
            title: const Text('Financial Report'),
            subtitle: const Text('Coming soon'),
            selected: currentRoute == Routes.financialReport,
            textColor: theme.colorScheme.onSurfaceVariant,
            iconColor: theme.colorScheme.onSurfaceVariant,
          ),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon,
    required this.label,
    required this.route,
    required this.currentRoute,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String route;
  final String currentRoute;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      selected: currentRoute == route,
      selectedTileColor: Theme.of(context).colorScheme.secondaryContainer,
      onTap: onTap,
    );
  }
}

class _Expandable extends StatelessWidget {
  const _Expandable({
    required this.icon,
    required this.label,
    required this.currentRoute,
    required this.children,
  });

  final IconData icon;
  final String label;
  final String currentRoute;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      leading: Icon(icon),
      title: Text(label),
      initiallyExpanded: children.any(
        (child) => child is _Tile && child.route == currentRoute,
      ),
      childrenPadding: const EdgeInsets.only(left: 16),
      children: children,
    );
  }
}