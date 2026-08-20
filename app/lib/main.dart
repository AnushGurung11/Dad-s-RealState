import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'config.dart';
import 'screens/dashboard_screen.dart';
import 'screens/flats_screen.dart';
import 'screens/reports_screen.dart';
import 'screens/tenants_screen.dart';
import 'services/json_store.dart';
import 'services/prefs.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const RentTrackApp());
}

class RentTrackApp extends StatefulWidget {
  const RentTrackApp({super.key, this.store, this.prefs});

  /// Injectable for tests. When null, a real [LocalJsonStore] is created.
  final JsonStore? store;

  /// Injectable for tests. When null, real [SharedPreferences] are used.
  final Prefs? prefs;

  @override
  State<RentTrackApp> createState() => _RentTrackAppState();
}

class _RentTrackAppState extends State<RentTrackApp> {
  late JsonStore _store;
  late Prefs _prefs;
  String _month = monthKey(DateTime.now());
  int _tabIndex = 0;
  bool _ready = false;
  Object? _bootError;

  @override
  void initState() {
    super.initState();
    _store = widget.store ?? LocalJsonStore(directory: Directory(''));
    if (widget.prefs != null) {
      _prefs = widget.prefs!;
    }
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      if (widget.store == null) {
        final dir = await getApplicationDocumentsDirectory();
        _store = LocalJsonStore(directory: dir);
        _store.onWriteError = (error, stackTrace) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not save data: $error')),
          );
        };
      }
      await _store.load();

      if (widget.prefs == null) {
        _prefs = await Prefs.load();
      }
      final savedMonth = await _prefs.currentMonth();
      if (savedMonth != null) {
        _month = savedMonth;
      }
    } catch (error) {
      _bootError = error;
    }
    if (!mounted) return;
    setState(() => _ready = true);
  }

  void _switchTab(int index) {
    setState(() => _tabIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.teal,
        brightness: Brightness.light,
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.teal,
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      themeMode: ThemeMode.system,
      home: _home(),
    );
  }

  Widget _home() {
    if (!_ready) {
      return const Scaffold(body: SizedBox.shrink());
    }
    if (_bootError != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48),
                const SizedBox(height: 16),
                const Text('Could not load app data.'),
                const SizedBox(height: 8),
                Text(
                  '$_bootError',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () {
                    setState(() {
                      _ready = false;
                      _bootError = null;
                    });
                    _bootstrap();
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return _Shell(
      store: _store,
      prefs: _prefs,
      initialMonth: _month,
      tabIndex: _tabIndex,
      onTabChanged: _switchTab,
      onMonthChanged: (month) {
        setState(() => _month = month);
        _prefs.setCurrentMonth(month);
      },
    );
  }
}

class _Shell extends StatefulWidget {
  const _Shell({
    required this.store,
    required this.prefs,
    required this.initialMonth,
    required this.tabIndex,
    required this.onTabChanged,
    required this.onMonthChanged,
  });

  final JsonStore store;
  final Prefs prefs;
  final String initialMonth;
  final int tabIndex;
  final ValueChanged<int> onTabChanged;
  final ValueChanged<String> onMonthChanged;

  @override
  State<_Shell> createState() => _ShellState();
}

class _ShellState extends State<_Shell> {
  late String _month;

  @override
  void initState() {
    super.initState();
    _month = widget.initialMonth;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: widget.tabIndex,
        children: [
          DashboardScreen(
            store: widget.store,
            month: _month,
            onGoToFlats: () => widget.onTabChanged(1),
          ),
          FlatsScreen(store: widget.store),
          TenantsScreen(store: widget.store),
          ReportsScreen(
            store: widget.store,
            initialMonth: _month,
            onMonthChanged: (month) {
              widget.onMonthChanged(month);
              setState(() => _month = month);
            },
            onGoToFlats: () => widget.onTabChanged(1),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: widget.tabIndex,
        onDestinationSelected: widget.onTabChanged,
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
            icon: Icon(Icons.assessment_outlined),
            selectedIcon: Icon(Icons.assessment),
            label: 'Reports',
          ),
        ],
      ),
    );
  }
}