import 'package:flutter/material.dart';

import '../config.dart';
import '../models/lease_check_setting.dart';
import '../services/check_service.dart';
import '../services/json_store.dart';
import '../services/notification_service.dart';
import '../utils/format.dart';
import '../widgets/empty_state.dart';
import '../widgets/summary_card.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    super.key,
    required this.store,
    required this.notifications,
    required this.onGoToFlats,
  });

  final JsonStore store;
  final NotificationService notifications;
  final VoidCallback onGoToFlats;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Future<void> _markPaid(LeaseCheckSetting setting) async {
    final result = CheckService.markPaid(setting, DateTime.now());
    setState(() {
      widget.store.upsertCheckSetting(result.setting);
      widget.store.upsertCheckRecord(result.record);
    });
    await widget.notifications.syncFor(result.setting);
  }

  String _flatName(String flatId) {
    for (final flat in widget.store.flats) {
      if (flat.id == flatId) return flat.name;
    }
    return 'Unknown flat';
  }

  String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

  Widget _checkCard(
    LeaseCheckSetting setting, {
    required String flatName,
  }) {
    final owner = setting.ownerName.trim().isEmpty
        ? 'No owner set'
        : setting.ownerName;
    return Card(
      child: ListTile(
        leading: CircleAvatar(child: const Icon(Icons.receipt_long_outlined)),
        title: Text('$flatName · $owner'),
        subtitle: Text(
          '${formatMoneyShort(setting.amount)} · '
          'due ${_formatDate(setting.nextDueDate)}',
        ),
        trailing: FilledButton.tonal(
          onPressed: () => _markPaid(setting),
          child: const Text('Mark paid'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final today = DateTime.now();

    final beds = store.beds;
    final occupied = beds.where((b) => b.tenantId != null).length;
    final vacant = beds.length - occupied;

    final due = CheckService.dueThisAndNextMonth(
      store.leaseCheckSettings,
      today,
    );
    final currentMonth = monthKey(today);
    final nextMonth = monthKey(DateTime(today.year, today.month + 1, 1));
    final dueThisMonth =
        due.where((s) => monthKey(s.nextDueDate) == currentMonth).toList();
    final dueNextMonth =
        due.where((s) => monthKey(s.nextDueDate) == nextMonth).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Row(
            children: [
              Expanded(
                child: SummaryCard(
                  title: 'Flats',
                  value: '${store.flats.length}',
                  icon: Icons.apartment,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SummaryCard(
                  title: 'Beds occupied',
                  value: '$occupied',
                  icon: Icons.person,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SummaryCard(
                  title: 'Beds vacant',
                  value: '$vacant',
                  icon: Icons.bed_outlined,
                  color: Theme.of(context).colorScheme.tertiary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (store.flats.isEmpty)
            EmptyState(
              icon: Icons.home_work_outlined,
              message: 'Add a flat to start tracking your lease checks.',
              actionLabel: 'Go to Flats',
              onAction: widget.onGoToFlats,
            )
          else ...[
            if (dueThisMonth.isNotEmpty) ...[
              Text(
                'Checks due this month',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              ...dueThisMonth.map(
                (setting) => _checkCard(
                  setting,
                  flatName: _flatName(setting.flatId),
                ),
              ),
              const SizedBox(height: 16),
            ],
            if (dueNextMonth.isNotEmpty) ...[
              Text(
                'Checks due next month',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              ...dueNextMonth.map(
                (setting) => _checkCard(
                  setting,
                  flatName: _flatName(setting.flatId),
                ),
              ),
              const SizedBox(height: 16),
            ],
            if (due.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'No checks due in the next 2 months.',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}