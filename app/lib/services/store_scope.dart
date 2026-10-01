import 'package:flutter/widgets.dart';

import 'json_store.dart';

/// Provides the app's [JsonStore] to the widget tree. Screens read it via
/// [StoreScope.of] and never touch files or construct services themselves.
class StoreScope extends InheritedWidget {
  const StoreScope({super.key, required this.store, required super.child});

  final JsonStore store;

  static JsonStore of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<StoreScope>()!.store;

  /// The store, or `null` when no [StoreScope] is mounted. Lets widgets that
  /// can degrade gracefully (e.g. the month jump menu) probe before reading.
  static JsonStore? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<StoreScope>()?.store;

  @override
  bool updateShouldNotify(StoreScope oldWidget) => store != oldWidget.store;
}
