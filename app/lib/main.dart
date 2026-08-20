import 'package:flutter/material.dart';

import 'config.dart';
import 'navigation/app_drawer.dart';
import 'navigation/routes.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const RentTrackApp());
}

class RentTrackApp extends StatelessWidget {
  const RentTrackApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: appLightTheme,
      darkTheme: appDarkTheme,
      themeMode: ThemeMode.system,
      home: const AppShell(),
    );
  }
}

/// App shell: AppBar (hamburger + current screen title), left drawer, and a
/// body routed via the named routes in [Routes].
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final GlobalKey<NavigatorState> _bodyNavKey = GlobalKey<NavigatorState>();
  late final _RouteTitleObserver _observer;
  String _currentRoute = Routes.dashboard;

  @override
  void initState() {
    super.initState();
    _observer = _RouteTitleObserver((name) {
      if (!mounted || name == _currentRoute) return;
      setState(() => _currentRoute = name);
    });
  }

  void _navigateTo(String route) {
    if (route == _currentRoute) return;
    _bodyNavKey.currentState?.pushReplacementNamed(route);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            tooltip: 'Open navigation menu',
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: Text(routeTitles[_currentRoute] ?? AppConfig.appName),
      ),
      drawer: AppDrawer(currentRoute: _currentRoute, onSelect: _navigateTo),
      body: Navigator(
        key: _bodyNavKey,
        initialRoute: Routes.dashboard,
        onGenerateRoute: buildRoute,
        observers: [_observer],
      ),
    );
  }
}

class _RouteTitleObserver extends NavigatorObserver {
  _RouteTitleObserver(this.onRouteChanged);

  final ValueChanged<String> onRouteChanged;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _sync(route);

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) =>
      _sync(newRoute);

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _sync(previousRoute);

  void _sync(Route<dynamic>? route) {
    final name = route?.settings.name;
    if (name != null) onRouteChanged(name);
  }
}