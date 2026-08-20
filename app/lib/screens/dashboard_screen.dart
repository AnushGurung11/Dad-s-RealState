import 'package:flutter/material.dart';

import '../services/json_store.dart';
import '../services/payment_service.dart';
import '../services/report_service.dart';
import '../utils/format.dart';
import '../widgets/empty_state.dart';
import '../widgets/summary_card.dart';
import 'person_history_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    super.key,
    required this.store,
    required this.month,
    required this.onGoToFlats,
  });

  final JsonStore store;
  final String month;
  final VoidCallback onGoToFlats;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final month = widget.month;

    final beds = store.beds;
    final occupied = beds.where((b) => b.tenantId != null).length;
    final vacant = beds.length - occupied;

    final report = ReportService.dashboardTotals(
      payments: store.payments,
      expenses: store.expenses,
      month: month,
    );

    final overdue = PaymentService.overdueTenants(
      payments: store.payments,
      people: store.people,
      month: month,
    );

    double owedBy(String personId) {
      var owed = 0.0;
      for (final p in store.payments.where((p) => p.personId == personId)) {
        if (p.month == month) owed += p.amountDue - p.amountPaid;
      }
      return owed;
    }

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
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: SummaryCard(
                  title: 'Beds vacant',
                  value: '$vacant',
                  icon: Icons.bed_outlined,
                  color: Theme.of(context).colorScheme.tertiary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SummaryCard(
                  title: 'Net ($month)',
                  value: formatMoneySigned(report.net),
                  icon: Icons.payments_outlined,
                  color: report.net < 0
                      ? Colors.red.shade600
                      : Colors.green.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text('Who owes what — $month',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (store.flats.isEmpty)
            EmptyState(
              icon: Icons.home_work_outlined,
              message: 'Add a flat, bed and tenant to see the dashboard summary.',
              actionLabel: 'Go to Flats',
              onAction: widget.onGoToFlats,
            )
          else if (overdue.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'No outstanding payments for $month.',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
            )
          else
            ...overdue.map(
              (person) => Card(
                child: ListTile(
                  leading: CircleAvatar(child: const Icon(Icons.person_outline)),
                  title: Text(person.name),
                  subtitle: Text('Owes ${formatMoneyShort(owedBy(person.id))}'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => PersonHistoryScreen(
                          store: store,
                          person: person,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}