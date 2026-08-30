import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'config.dart';
import 'navigation/bottom_nav.dart';
import 'navigation/routes.dart';
import 'services/archive_service.dart';
import 'services/json_store.dart';
import 'services/store_scope.dart';
import 'theme/app_theme.dart';
import 'widgets/lucky_wordmark.dart';

/// Simulated Android status bar — 28px, mono time, signal/WiFi/battery.
class AppStatusBar extends StatelessWidget {
  const AppStatusBar({super.key});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final time = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    return Container(
      height: 28,
      color: appBg,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Text(time,
              style: const TextStyle(
                fontFamily: 'SF Mono',
                fontFamilyFallback: ['ui-monospace', 'monospace'],
                fontSize: 12,
                color: Color(0xB3F5F5F7),
                fontFeatures: [FontFeature.tabularFigures()],
              )),
          const Spacer(),
          // signal bars
          Row(
            children: List.generate(
              4,
              (i) => Container(
                width: 3,
                height: 4 + i * 2,
                margin: EdgeInsets.only(left: i == 0 ? 0 : 2),
                decoration: BoxDecoration(
                  color: i < 3 ? const Color(0xB3F5F5F7) : const Color(0xFF2C2C32),
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          const Icon(Icons.wifi, size: 14, color: Color(0xB3F5F5F7)),
          const SizedBox(width: 6),
          Container(
            width: 24,
            height: 12,
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0x66F5F5F7)),
              borderRadius: BorderRadius.circular(3),
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                width: 16,
                height: 8,
                margin: const EdgeInsets.all(1),
                decoration: BoxDecoration(color: const Color(0xFF34C759), borderRadius: BorderRadius.circular(1)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

void main() {
  runApp(const LuckyApp());
}

class LuckyApp extends StatelessWidget {
  const LuckyApp({super.key, this.createStore});

  /// Optional override for where the [JsonStore] comes from. Tests inject an
  /// in-memory store here; production uses the file-backed local store.
  final JsonStore Function()? createStore;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: appDarkTheme,
      darkTheme: appDarkTheme,
      themeMode: ThemeMode.dark,
      builder: (context, child) => StoreLoader(
        createStore: createStore,
        child: Container(
          color: appBg,
          child: child ?? const SizedBox.shrink(),
        ),
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
            backgroundColor: appBg,
            body: Center(
              child: Column(
                key: Key('splash_wordmark'),
                mainAxisSize: MainAxisSize.min,
                children: [
                  LuckyWordmark(size: 48),
                  SizedBox(height: 16),
                  Text('Saved', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 0.8, color: appText3)),
                ],
              ),
            ),
          );
        }
        return StoreScope(store: snapshot.data!, child: widget.child);
      },
    );
  }
}

/// App shell: AppBar (current screen title) + bottom NavigationBar.
/// Implements patch section 1 — replaces the old drawer.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final GlobalKey<NavigatorState> _bodyNavKey = GlobalKey<NavigatorState>();
  late final _RouteTitleObserver _observer;
  String _currentRoute = Routes.dashboard;
  bool _archiveSweepDone = false;

  @override
  void initState() {
    super.initState();
    _observer = _RouteTitleObserver((name) {
      if (!mounted || name == _currentRoute) return;
      setState(() => _currentRoute = name);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_archiveSweepDone) return;
    _archiveSweepDone = true;
    _runArchiveSweep();
  }

  void _runArchiveSweep() {
    final store = StoreScope.of(context);
    final (people, beds) = ArchiveService.checkAndArchive(
      store.people,
      store.beds,
      DateTime.now(),
    );
    store.runBatched(() {
      for (var i = 0; i < people.length; i++) {
        if (!identical(people[i], store.people[i])) {
          store.upsertPerson(people[i]);
        }
      }
      for (var i = 0; i < beds.length; i++) {
        if (!identical(beds[i], store.beds[i])) {
          store.upsertBed(beds[i]);
        }
      }
    });
  }

  void _navigateTo(String route) {
    if (route == _currentRoute) return;
    _bodyNavKey.currentState
        ?.pushNamedAndRemoveUntil(route, (r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final canPop = _bodyNavKey.currentState?.canPop() ?? false;
    final title = routeTitles[_currentRoute] ?? AppConfig.appName;
    return Scaffold(
      backgroundColor: appBg,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(80), // 28 status + 52 appbar
        child: Column(
          children: [
            const AppStatusBar(),
            AppBar(
              title: Text(title),
              leading: canPop
                  ? Padding(
                      padding: const EdgeInsets.all(8),
                      child: InkWell(
                        onTap: () => _bodyNavKey.currentState?.maybePop(),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(color: appAccentDim, borderRadius: BorderRadius.circular(12)),
                          child: const Icon(Icons.chevron_left, color: appAccent, size: 20),
                        ),
                      ),
                    )
                  : null,
              backgroundColor: const Color(0xEB09090B),
              elevation: 0,
            ),
          ],
        ),
      ),
      body: Navigator(
        key: _bodyNavKey,
        initialRoute: Routes.dashboard,
        onGenerateRoute: buildRoute,
        observers: [_observer],
      ),
      bottomNavigationBar: LuckyBottomNav(
        currentRoute: _currentRoute,
        onSelect: _navigateTo,
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