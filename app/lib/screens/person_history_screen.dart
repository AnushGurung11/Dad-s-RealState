import 'package:flutter/material.dart';

import '../models/person.dart';
import '../services/json_store.dart';
import '../utils/format.dart';

class PersonHistoryScreen extends StatelessWidget {
  const PersonHistoryScreen({
    super.key,
    required this.store,
    required this.person,
  });

  final JsonStore store;
  final Person person;

  String _bedLabel(String bedId) {
    final match = store.beds.where((b) => b.id == bedId);
    return match.isEmpty ? 'Unknown bed' : match.first.label;
  }

  @override
  Widget build(BuildContext context) {
    final payments = store.payments
        .where((p) => p.personId == person.id)
        .toList()
      ..sort((a, b) => b.month.compareTo(a.month));

    return Scaffold(
      appBar: AppBar(title: Text(person.name)),
      body: payments.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  'No payment history for ${person.name} yet.',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: payments.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final payment = payments[index];
                return Card(
                  child: ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.receipt_long)),
                    title: Text(payment.month),
                    subtitle: Text(
                      '${_bedLabel(payment.bedId)} · '
                      'Paid ${formatMoneyShort(payment.amountPaid)} of '
                      '${formatMoneyShort(payment.amountDue)}',
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.chevron_right),
                      onPressed: () => showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Text('Payment · ${payment.month}'),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Due: ${formatMoneyShort(payment.amountDue)}'),
                              Text('Paid: ${formatMoneyShort(payment.amountPaid)}'),
                              Text(
                                'Outstanding: ${formatMoneyShort(payment.amountDue - payment.amountPaid)}',
                              ),
                            ],
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Close'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}