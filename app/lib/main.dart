import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'config.dart';
import 'navigation/app_drawer.dart';
import 'navigation/routes.dart';
import 'services/json_store.dart';
import 'services/store_scope.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const RentTrackApp());
}

class RentTrackApp extends StatelessWidget {
  const RentTrackApp({super.key, this.createStore});

  /// Optional override for where the [JsonStore] comes from. Tests inject an
  /// in-memory store here; production uses the file-backed local store.
  final JsonStore Function()? createStore;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: appLightTheme,
      darkTheme: appDarkTheme,
      themeMode: ThemeMode.system,
      // The builder (not `home`) hosts StoreScope so every pushed route —
      // not just the shell — can resolve the store.
      builder: (context, child) => StoreLoader(
        createStore: createStore,
        child: child ?? const SizedBox.shrink(),
      ),
      home: const AppShell(),
    );
  }
}

/// Opens the [LocalJsonStore] before the UI renders and exposes it via
/// [StoreScope]. Shows a loading screen while data loads and a plain error
/// screen if loading fails (e.g. data written by a newer app version).
class StoreLoader extends StatefulWidget {
  const StoreLoader({
    super.key,
    required this.child,
    this.createStore,
  });

  final Widget child;
  final JsonStore Function()? createStore;

  @override
  State<StoreLoader> createState() => _StoreLoaderState();
}

class _StoreLoaderState extends State<StoreLoader> {
  late final Future<JsonStore> _storeFuture;

  @override
  void initState() {
    super.initState();
    _storeFuture = _openStore();
  }

  Future<JsonStore> _openStore() async {
    final override = widget.createStore;
    if (override != null) return override();
    final documents = await getApplicationDocumentsDirectory();
    final store = LocalJsonStore(
      directory: Directory(
        '${documents.path}${Platform.pathSeparator}${AppConfig.appName}',
      ),
    );
    await store.load();
    return store;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<JsonStore>(
      future: _storeFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Could not load your data.\n\n${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return StoreScope(store: snapshot.data!, child: widget.child);
      },
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