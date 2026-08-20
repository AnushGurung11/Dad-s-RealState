import 'package:flutter/material.dart';

import '../config.dart';
import '../models/payment.dart';
import '../models/person.dart';
import '../services/json_store.dart';
import '../services/tenure_service.dart';
import '../widgets/empty_state.dart';
import 'person_history_screen.dart';

class TenantsScreen extends StatefulWidget {
  const TenantsScreen({super.key, required this.store});

  final JsonStore store;

  @override
  State<TenantsScreen> createState() => _TenantsScreenState();
}

class _TenantsScreenState extends State<TenantsScreen> {
  String _query = '';
  bool _showPast = false;

  bool _isPast(Person person) => !person.hasBed && person.vacatedDate != null;

  Future<void> _openPerson(Person person) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PersonHistoryScreen(
          store: widget.store,
          person: person,
        ),
      ),
    );
    setState(() {});
  }

  Color _avatarColor(String name) {
    final hues = [
      Colors.teal,
      Colors.indigo,
      Colors.deepOrange,
      Colors.brown,
      Colors.blueGrey,
      Colors.deepPurple,
    ];
    var hash = 0;
    for (final c in name.codeUnits) {
      hash = (hash * 31 + c) & 0x7fffffff;
    }
    return hues[hash % hues.length];
  }

  @override
  Widget build(BuildContext context) {
    final all = widget.store.people.where((p) {
      if (_query.trim().isNotEmpty &&
          !p.name.toLowerCase().contains(_query.trim().toLowerCase())) {
        return false;
      }
      return _showPast ? _isPast(p) : !_isPast(p);
    }).toList();

    // Group active tenants by flat.
    final groups = <String, List<Person>>{};
    for (final person in all) {
      final bed =
          widget.store.beds.where((b) => b.id == person.bedId).firstOrNull;
      String key;
      if (bed == null) {
        key = 'No bed assigned';
      } else {
        key = widget.store.flats
                .where((f) => f.id == bed.flatId)
                .firstOrNull
                ?.name ??
            'Unknown flat';
      }
      groups.putIfAbsent(key, () => []).add(person);
    }

    final keys = groups.keys.toList()
      ..sort((a, b) => a == 'No bed assigned'
          ? 1
          : b == 'No bed assigned'
              ? -1
              : a.compareTo(b));

    return Scaffold(
      appBar: AppBar(title: const Text('Tenants')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: TextField(
              onChanged: (value) => setState(() => _query = value),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: 'Search tenants',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                isDense: true,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                  value: false,
                  label: Text('Active'),
                  icon: Icon(Icons.person),
                ),
                ButtonSegment(
                  value: true,
                  label: Text('Past'),
                  icon: Icon(Icons.person_off_outlined),
                ),
              ],
              selected: {_showPast},
              onSelectionChanged: (selection) =>
                  setState(() => _showPast = selection.first),
            ),
          ),
          Expanded(
            child: all.isEmpty
                ? _showPast
                    ? Center(
                        child: Text(
                          'No past tenants.',
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                color:
                                    Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      )
                    : EmptyState(
                        icon: Icons.group_outlined,
                        message:
                            'No tenants yet. Tap a vacant bed on the Flats tab '
                            'to assign a tenant.',
                      )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 88),
                    children: [
                      for (final key in keys) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(4, 12, 4, 6),
                          child: Text(
                            key,
                            style: Theme.of(context)
                                .textTheme
                                .labelLarge
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                          ),
                        ),
                        for (final person in groups[key]!)
                          _TenantTile(
                            person: person,
                            color: _avatarColor(person.name),
                            bedLabel: widget.store.beds
                                .where((b) => b.id == person.bedId)
                                .firstOrNull
                                ?.label,
                            store: widget.store,
                            onTap: () => _openPerson(person),
                          ),
                        const SizedBox(height: 4),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _TenantTile extends StatelessWidget {
  const _TenantTile({
    required this.person,
    required this.color,
    required this.bedLabel,
    required this.store,
    required this.onTap,
  });

  final Person person;
  final Color color;
  final String? bedLabel;
  final JsonStore store;
  final VoidCallback onTap;

  PaymentStatus? _currentMonthStatus() {
    final month = monthKey(DateTime.now());
    Payment? latest;
    for (final p in store.payments) {
      if (p.personId == person.id &&
          p.type == PaymentType.rent &&
          p.month == month) {
        latest = p;
      }
    }
    return latest?.status;
  }

  @override
  Widget build(BuildContext context) {
    final isActive = !(person.hasBed == false && person.vacatedDate != null);
    final subtitle = isActive
        ? bedLabel == null
            ? 'No bed assigned'
            : person.joinDate == null
                ? bedLabel!
                : '$bedLabel · '
                    'Joined ${person.joinDate!.day}/${person.joinDate!.month}/${person.joinDate!.year}'
        : 'Left ${person.vacatedDate!.day}/${person.vacatedDate!.month}/${person.vacatedDate!.year} · '
            'Stayed ${TenureService.effectiveStayMonths(person)}mo';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        enabled: isActive,
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.15),
          child: Icon(Icons.person, color: color),
        ),
        title: Text(
          person.name,
          style: isActive ? null : const TextStyle(color: Colors.grey),
        ),
        subtitle: Text(
          subtitle,
          style: isActive ? null : const TextStyle(color: Colors.grey),
        ),
        trailing: isActive ? _StatusBadge(status: _currentMonthStatus()) : null,
        onTap: onTap,
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final PaymentStatus? status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      null => ('—', null),
      PaymentStatus.paid => ('Paid', Colors.green.shade700),
      PaymentStatus.partial => ('Partial', Colors.orange.shade800),
      PaymentStatus.unpaid => ('Overdue', Theme.of(context).colorScheme.error),
    };
    if (color == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color),
      ),
    );
  }
}