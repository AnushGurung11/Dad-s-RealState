// ignore_for_file: constant_identifier_names
import 'package:flutter/material.dart';

/// Named icon identities — central registry per spec.
/// Each entry maps to a SVG path in [PATHS] and a Material [IconData] fallback.
/// To swap in custom SVG, replace only the path string in [PATHS].
enum AppIcon {
  grid, // Overview
  building, // Flats
  people, // Tenants
  wallet, // Finance
  dots, // More
  pencil, // edit
  trash, // delete
  plus, // add
  close, // dismiss
  arrowRight,
  arrowLeft,
  bed,
  search,
  person,
  camera,
  receipt,
  calendar,
  check,
  warning,
  info,
  download,
  upload,
  chart,
  archive,
  lock,
  bolt, // electricity
  drop, // water
  tool, // maintenance
  broom, // cleaning
  box, // other
  wifi,
  phone,
  home,
  dashboard,
  apartment,
  group,
  accountWallet,
  moreHoriz,
}

/// SVG path data for each icon — stroke="currentColor" strokeWidth 1.6.
/// These are Lucide-style outlines. Replace path content to customize.
const Map<AppIcon, String> PATHS = {
  AppIcon.grid: 'M3 3h7v7H3z M14 3h7v7h-7z M3 14h7v7H3z M14 14h7v7h-7z',
  AppIcon.building: 'M3 21V3h8v18 M9 9h4 M9 13h4 M9 17h4 M14 8h4 M14 12h4 M14 16h4',
  AppIcon.people: 'M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2 M9 11a4 4 0 1 0 0-8 4 4 0 0 0 0 8z M22 21v-2a4 4 0 0 0-3-3.87 M16 3.13a4 4 0 0 1 0 7.75',
  AppIcon.wallet: 'M19 7V5a2 2 0 0 0-2-2H5a2 2 0 0 0-2 2v12a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2v-2 M16 11h6 M19 11a2 2 0 1 0 0 4 2 2 0 0 0 0-4z',
  AppIcon.dots: 'M12 13a1 1 0 1 0 0-2 1 1 0 0 0 0 2z M19 13a1 1 0 1 0 0-2 1 1 0 0 0 0 2z M5 13a1 1 0 1 0 0-2 1 1 0 0 0 0 2z',
  AppIcon.pencil: 'M17 3a2.83 2.83 0 1 1 4 4L7.5 20.5 2 22l1.5-5.5L17 3z',
  AppIcon.trash: 'M3 6h18 M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a1 1 0 0 1 1-1h4a1 1 0 0 1 1 1v2',
  AppIcon.plus: 'M12 5v14 M5 12h14',
  AppIcon.close: 'M18 6L6 18 M6 6l12 12',
  AppIcon.arrowRight: 'M9 18l6-6-6-6',
  AppIcon.arrowLeft: 'M15 18l-6-6 6-6',
  AppIcon.bed: 'M2 12h20 M2 12v6h20v-6 M4 12V9a2 2 0 0 1 2-2h2a2 2 0 0 1 2 2v3 M14 7h4a2 2 0 0 1 2 2v3',
  AppIcon.search: 'M21 21l-4.3-4.3 M10.5 18a7.5 7.5 0 1 1 0-15 7.5 7.5 0 0 1 0 15z',
  AppIcon.person: 'M19 21v-2a4 4 0 0 0-4-4H9a4 4 0 0 0-4 4v2 M12 11a4 4 0 1 0 0-8 4 4 0 0 0 0 8z',
  AppIcon.camera: 'M14.5 4h-5L7 7H4a2 2 0 0 0-2 2v8a2 2 0 0 0 2 2h16a2 2 0 0 0 2-2V9a2 2 0 0 0-2-2h-3l-2.5-3z M12 15a3.5 3.5 0 1 0 0-7 3.5 3.5 0 0 0 0 7z',
  AppIcon.receipt: 'M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z M14 2v6h6 M10 13H8 M16 17H8 M13 9H8',
  AppIcon.calendar: 'M8 2v4 M16 2v4 M3 8h18 M5 4h14a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V6a2 2 0 0 1 2-2z',
  AppIcon.check: 'M20 6L9 17l-5-5',
  AppIcon.warning: 'M10.29 3.86L1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0z M12 9v4 M12 17h.01',
  AppIcon.info: 'M12 16v-4 M12 8h.01 M12 22a10 10 0 1 0 0-20 10 10 0 0 0 0 20z',
  AppIcon.download: 'M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4 M7 10l5 5 5-5 M12 15V3',
  AppIcon.upload: 'M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4 M17 8l-5-5-5 5 M12 3v12',
  AppIcon.chart: 'M3 3v18h18 M7 16l4-4 3 3 5-7',
  AppIcon.archive: 'M21 8v13H3V8 M1 3h22v5H1z M10 12h4',
  AppIcon.lock: 'M19 11H5a2 2 0 0 0-2 2v7a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7a2 2 0 0 0-2-2z M7 11V7a5 5 0 0 1 10 0v4',
  AppIcon.bolt: 'M13 2L3 14h9l-1 8 10-12h-9l1-8z',
  AppIcon.drop: 'M12 2.69l5.66 5.66a8 8 0 1 1-11.31 0z',
  AppIcon.tool: 'M14.7 6.3a1 1 0 0 0 0 1.4l1.6 1.6a1 1 0 0 0 1.4 0l3.77-3.77a6 6 0 0 1-7.94 7.94l-6.91 6.91a2.12 2.12 0 0 1-3-3l6.91-6.91a6 6 0 0 1 7.94-7.94l-3.76 3.76z',
  AppIcon.broom: 'M4 16v-2.38c0-1.27.2-2.45.57-3.5L16 4l4 4-5.6 11.43A6.98 6.98 0 0 1 11 20H4z M9 19l3-3',
  AppIcon.box: 'M21 16V8a2 2 0 0 0-1-1.73l-7-4a2 2 0 0 0-2 0l-7 4A2 2 0 0 0 3 8v8a2 2 0 0 0 1 1.73l7 4a2 2 0 0 0 2 0l7-4A2 2 0 0 0 21 16z',
  AppIcon.wifi: 'M5 12.55a11 11 0 0 1 14 0 M8.5 15.5a5 5 0 0 1 7 0 M12 20h.01 M12 18a1 1 0 1 0 0 2 1 1 0 0 0 0-2z',
  AppIcon.phone: 'M22 16.92v3a2 2 0 0 1-2.18 2 19.79 19.79 0 0 1-8.63-3.07A19.5 19.5 0 0 1 5 12.18 19.79 19.79 0 0 1 1.93 3.56 2 2 0 0 1 3.92 1.5h3a2 2 0 0 1 2 1.72c.12 1.33.39 2.65.8 3.92a2 2 0 0 1-.57 2.06L8 10.57a16 16 0 0 0 5.43 5.43l1.37-1.15a2 2 0 0 1 2.06-.57c1.27.41 2.59.68 3.92.8a2 2 0 0 1 1.72 2z',
  AppIcon.home: 'M3 9l9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z M9 22V12h6v10',
};

/// Maps AppIcon to Material IconData for quick fallback without flutter_svg.
IconData iconDataFor(AppIcon icon) {
  return switch (icon) {
    AppIcon.grid => Icons.grid_view_rounded,
    AppIcon.building => Icons.apartment_outlined,
    AppIcon.people => Icons.group_outlined,
    AppIcon.wallet => Icons.account_balance_wallet_outlined,
    AppIcon.dots => Icons.more_horiz,
    AppIcon.pencil => Icons.edit_outlined,
    AppIcon.trash => Icons.delete_outline,
    AppIcon.plus => Icons.add,
    AppIcon.close => Icons.close,
    AppIcon.arrowRight => Icons.chevron_right,
    AppIcon.arrowLeft => Icons.chevron_left,
    AppIcon.bed => Icons.bed_outlined,
    AppIcon.search => Icons.search,
    AppIcon.person => Icons.person_outline,
    AppIcon.camera => Icons.photo_camera_outlined,
    AppIcon.receipt => Icons.receipt_long_outlined,
    AppIcon.calendar => Icons.calendar_today_outlined,
    AppIcon.check => Icons.check,
    AppIcon.warning => Icons.warning_amber,
    AppIcon.info => Icons.info_outline,
    AppIcon.download => Icons.download_outlined,
    AppIcon.upload => Icons.upload_outlined,
    AppIcon.chart => Icons.bar_chart_outlined,
    AppIcon.archive => Icons.archive_outlined,
    AppIcon.lock => Icons.lock_outline,
    AppIcon.bolt => Icons.bolt_outlined,
    AppIcon.drop => Icons.water_drop_outlined,
    AppIcon.tool => Icons.build_outlined,
    AppIcon.broom => Icons.cleaning_services_outlined,
    AppIcon.box => Icons.inventory_2_outlined,
    AppIcon.wifi => Icons.wifi,
    AppIcon.phone => Icons.phone_outlined,
    AppIcon.home => Icons.home_outlined,
    AppIcon.dashboard => Icons.dashboard_outlined,
    AppIcon.apartment => Icons.apartment_outlined,
    AppIcon.group => Icons.group_outlined,
    AppIcon.accountWallet => Icons.account_balance_wallet_outlined,
    AppIcon.moreHoriz => Icons.more_horiz,
  };
}

/// Unified icon widget — 24x24 default, 1.6 stroke equivalent via Material size 22.
class AppIconWidget extends StatelessWidget {
  const AppIconWidget(this.icon, {super.key, this.size = 22, this.color});

  final AppIcon icon;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Icon(
      iconDataFor(icon),
      size: size,
      color: color,
    );
  }
}
