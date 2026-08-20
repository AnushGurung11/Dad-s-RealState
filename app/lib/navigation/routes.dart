import 'package:flutter/material.dart';

import '../screens/placeholder_screen.dart';

/// Named routes for the whole app. Chunks 2-8 replace placeholder bodies with
/// real screens while keeping these names stable.
abstract final class Routes {
  static const String dashboard = '/';
  static const String flats = '/flats';
  static const String tenantsAdd = '/tenants/add';
  static const String tenantsAssign = '/tenants/assign';
  static const String paymentsFlatLease = '/payments/flat-lease';
  static const String paymentsTenantRent = '/payments/tenant-rent';
  static const String historyFlatLease = '/history/flat-lease';
  static const String historyTenantRent = '/history/tenant-rent';
  static const String expenses = '/expenses';
  static const String settingsNotifications = '/settings/notifications';
  static const String settingsArchive = '/settings/archive';
  static const String financialReport = '/report';
}

/// Display title for each route (used by the AppBar).
const Map<String, String> routeTitles = {
  Routes.dashboard: 'Dashboard',
  Routes.flats: 'Flats',
  Routes.tenantsAdd: 'Add member',
  Routes.tenantsAssign: 'Assign',
  Routes.paymentsFlatLease: 'Flat Lease Payment',
  Routes.paymentsTenantRent: 'Tenant Rent Payment',
  Routes.historyFlatLease: 'Flat Lease History',
  Routes.historyTenantRent: 'Tenant Rent History',
  Routes.expenses: 'Expenses',
  Routes.settingsNotifications: 'Notifications',
  Routes.settingsArchive: 'Archive',
  Routes.financialReport: 'Financial Report',
};

/// Builds the route for [settings], resolving the screen title from
/// [routeTitles]. Routes not yet implemented render a placeholder body.
Route<dynamic> buildRoute(RouteSettings settings) {
  final title = routeTitles[settings.name] ?? settings.name ?? '';
  return MaterialPageRoute<void>(
    settings: settings,
    builder: (_) => PlaceholderScreen(title: title),
  );
}