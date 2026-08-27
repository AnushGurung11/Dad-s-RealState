import 'package:flutter/material.dart';

import '../screens/add_tenant_screen.dart';
import '../screens/archive_flats_screen.dart';
import '../screens/archive_tenants_screen.dart';
import '../screens/assign_screen.dart';
import '../screens/cheque_payment_flat_screen.dart';
import '../screens/dashboard_screen.dart';
import '../screens/edit_tenant_screen.dart';
import '../screens/expenses_screen.dart';
import '../screens/flat_detail_screen.dart';
import '../screens/flat_lease_history_screen.dart';
import '../screens/flats_screen.dart';
import '../screens/payment_history_screen.dart';
import '../screens/payments_screen.dart';
import '../screens/person_detail_screen.dart';
import '../screens/placeholder_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/tenants_screen.dart';
import '../screens/termination_flow_screen.dart';
import '../screens/tenant_rent_history_screen.dart';
import '../screens/tenant_rent_payment_screen.dart';

/// Named routes for the whole app. Screens swap bodies while these names
/// stay stable.
abstract final class Routes {
  static const String dashboard = '/';
  static const String flats = '/flats';
  static const String flatDetail = '/flats/detail';
  static const String tenants = '/tenants';
  static const String tenantsAdd = '/tenants/add';
  static const String tenantsAssign = '/tenants/assign';
  static const String tenantsDetail = '/tenants/detail';
  static const String tenantsEdit = '/tenants/edit';
  static const String tenantsTerminate = '/tenants/terminate';
  static const String payments = '/payments';
  static const String paymentsFlatLease = '/payments/flat-lease';
  static const String paymentsTenantRent = '/payments/tenant-rent';
  static const String paymentHistory = '/payments/history';
  static const String historyFlatLease = '/history/flat-lease';
  static const String historyTenantRent = '/history/tenant-rent';
  static const String expenses = '/expenses';
  static const String settings = '/settings';
  static const String settingsArchive = '/settings/archive';
  static const String archiveTenants = '/archive/tenants';
  static const String archiveFlats = '/archive/flats';
  static const String financialReport = '/report';
}

/// Display title for each route (used by the AppBar).
const Map<String, String> routeTitles = {
  Routes.dashboard: 'Dashboard',
  Routes.flats: 'Flats',
  Routes.flatDetail: 'Flat',
  Routes.tenants: 'Tenants',
  Routes.tenantsAdd: 'Add tenant',
  Routes.tenantsAssign: 'Assign',
  Routes.tenantsDetail: 'Tenant',
  Routes.tenantsEdit: 'Edit tenant',
  Routes.tenantsTerminate: 'End tenure early',
  Routes.payments: 'Payments',
  Routes.paymentsFlatLease: 'Cheque Payment (Flat)',
  Routes.paymentsTenantRent: 'Tenant Rent Payment',
  Routes.paymentHistory: 'Payment History',
  Routes.historyFlatLease: 'Flat Lease History',
  Routes.historyTenantRent: 'Tenant Rent History',
  Routes.expenses: 'Expenses',
  Routes.settings: 'Settings',
  Routes.settingsArchive: 'Settings',
  Routes.archiveTenants: 'Archived Tenants',
  Routes.archiveFlats: 'Archive Flats',
  Routes.financialReport: 'Financial Report',
};

/// Builds the route for [settings], resolving the screen title from
/// [routeTitles]. Routes not yet implemented render a placeholder body.
Route<dynamic> buildRoute(RouteSettings settings) {
  MaterialPageRoute<void> material(Widget Function() builder) =>
      MaterialPageRoute<void>(settings: settings, builder: (_) => builder());

  switch (settings.name) {
    case Routes.dashboard:
      return material(DashboardScreen.new);
    case Routes.flats:
      return material(FlatsScreen.new);
    case Routes.flatDetail:
      final flatId = settings.arguments as String?;
      return material(
        () => FlatDetailScreen(flatId: flatId ?? ''),
      );
    case Routes.tenants:
      return material(TenantsScreen.new);
    case Routes.tenantsAdd:
      return material(AddTenantScreen.new);
    case Routes.tenantsAssign:
      final bedId = settings.arguments is String
          ? settings.arguments as String?
          : null;
      return material(() => AssignScreen(initialBedId: bedId));
    case Routes.tenantsDetail:
      final personId = settings.arguments as String?;
      return material(
        () => PersonDetailScreen(personId: personId ?? ''),
      );
    case Routes.tenantsEdit:
      final personId = settings.arguments as String?;
      return material(
        () => EditTenantScreen(personId: personId ?? ''),
      );
    case Routes.tenantsTerminate:
      final personId = settings.arguments as String?;
      return material(
        () => TerminationFlowScreen(personId: personId ?? ''),
      );
    case Routes.payments:
      return material(PaymentsScreen.new);
    case Routes.paymentsFlatLease:
      return material(ChequePaymentFlatScreen.new);
    case Routes.paymentsTenantRent:
      return material(TenantRentPaymentScreen.new);
    case Routes.historyFlatLease:
      return material(FlatLeaseHistoryScreen.new);
    case Routes.historyTenantRent:
      return material(TenantRentHistoryScreen.new);
    case Routes.paymentHistory:
      return material(PaymentHistoryScreen.new);
    case Routes.expenses:
      return material(ExpensesScreen.new);
    case Routes.settings:
      return material(SettingsScreen.new);
    case Routes.settingsArchive:
      return material(
        () => const SettingsScreen(initialSection: SettingsSection.archive),
      );
    case Routes.archiveTenants:
      return material(ArchiveTenantsScreen.new);
    case Routes.archiveFlats:
      return material(ArchiveFlatsScreen.new);
    default:
      final title = routeTitles[settings.name] ?? settings.name ?? '';
      return material(() => PlaceholderScreen(title: title));
  }
}
