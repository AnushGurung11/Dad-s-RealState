import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart'
    hide Person;

import '../models/person.dart';
import '../navigation/routes.dart';
import '../services/notification_service.dart';
import '../services/prefs.dart';
import '../services/store_scope.dart';

/// Which part of the settings screen to land on.
enum SettingsSection { notifications, archive }

/// Settings: one global notifications switch gating all lease-cheque
/// reminders, plus the Archive — a searchable list of auto-archived tenants.
/// Tapping an archived tenant opens their read-only detail (no Renew action).
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    this.initialSection,
    this.notificationService,
    this.prefs,
  });

  /// Scrolls to this section right after the first frame (used by the
  /// drawer's Archive entry).
  final SettingsSection? initialSection;

  /// Injectable for tests; defaults to the real plugin-backed scheduler.
  final NotificationService? notificationService;

  /// Injectable for tests; defaults to [Prefs.load].
  final Prefs? prefs;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final GlobalKey _archiveHeaderKey = GlobalKey();
  NotificationService? _notificationService;
  Prefs? _prefs;
  bool? _notificationsEnabled;
  String _query = '';

  @override
  void initState() {
    super.initState();
    if (widget.initialSection == SettingsSection.archive) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final context = _archiveHeaderKey.currentContext;
        if (context != null) {
          Scrollable.ensureVisible(
            context,
            duration: const Duration(milliseconds: 300),
          );
        }
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _notificationService ??= widget.notificationService ??
        NotificationService(
          LocalNotificationScheduler(FlutterLocalNotificationsPlugin()),
        );
    if (_prefs == null) {
      final injected = widget.prefs;
      if (injected != null) {
        _prefs = injected;
        _loadToggle();
      } else {
        Prefs.load().then((prefs) {
          if (!mounted) return;
          setState(() => _prefs = prefs);
          _loadToggle();
        });
      }
    }
  }

  Future<void> _loadToggle() async {
    final enabled = await _prefs!.notificationsEnabled();
    if (!mounted) return;
    setState(() => _notificationsEnabled = enabled);
  }

  Future<void> _onToggleChanged(bool value) async {
    setState(() => _notificationsEnabled = value);
    // Resolve everything needed before the async gap.
    final settings = StoreScope.of(context).leaseChequeSettings;
    final service = _notificationService!;
    await _prefs!.setNotificationsEnabled(value);
    if (value) {
      // Reschedule from the CURRENT due dates, never stale ones.
      await service.rescheduleAll(settings);
    } else {
      await service.disableAll(settings);
    }
  }

  String? _dateText(DateTime? date) => date == null
      ? null
      : '${date.year}-${date.month.toString().padLeft(2, '0')}-'
          '${date.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final archived = store.people.where((p) => p.archived).toList()
      ..sort((a, b) => (b.archivedAt ?? DateTime(0))
          .compareTo(a.archivedAt ?? DateTime(0)));
    final needle = _query.trim().toLowerCase();
    final filtered = needle.isEmpty
        ? archived
        : archived
            .where((p) => p.name.toLowerCase().contains(needle))
            .toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Notifications', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Card(
          margin: EdgeInsets.zero,
          child: SwitchListTile(
            value: _notificationsEnabled ?? false,
            onChanged:
                _notificationsEnabled == null ? null : _onToggleChanged,
            title: const Text('Lease cheque reminders'),
            subtitle: const Text('One switch for every flat'),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Archive',
          key: _archiveHeaderKey,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        TextField(
          key: const Key('archive_search_field'),
          decoration: const InputDecoration(
            hintText: 'Search archived tenants',
            prefixIcon: Icon(Icons.search),
            border: OutlineInputBorder(),
          ),
          onChanged: (value) => setState(() => _query = value),
        ),
        const SizedBox(height: 8),
        if (archived.isEmpty)
          Text(
            'No archived tenants.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          )
        else if (filtered.isEmpty)
          Text(
            'No matches for "$_query".',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          )
        else
          ...filtered.map(_archiveTile),
      ],
    );
  }

  Widget _archiveTile(Person person) {
    final store = StoreScope.of(context);
    final flat =
        store.flats.where((f) => f.id == person.flatId).firstOrNull;
    final bed = store.beds.where((b) => b.id == person.bedId).firstOrNull;
    final former = [flat?.name, bed?.label].whereType<String>().join(' · ');

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        key: ValueKey('archive-person-${person.id}'),
        leading: const Icon(Icons.person_off_outlined),
        title: Text(person.name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (former.isNotEmpty) Text(former),
            Text(
              'Archived ${_dateText(person.archivedAt) ?? '—'} · '
              'Vacated ${_dateText(person.vacatedDate) ?? '—'}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
        isThreeLine: true,
        onTap: () => Navigator.pushNamed(
          context,
          Routes.tenantsDetail,
          arguments: person.id,
        ),
      ),
    );
  }
}
