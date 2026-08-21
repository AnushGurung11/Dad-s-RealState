import 'package:flutter/material.dart';

import '../models/payment.dart';
import '../models/person.dart';
import '../services/store_scope.dart';
import '../utils/format.dart';
import '../widgets/tenant_picker_list.dart';

/// Tenant Rent History: searchable, flat-grouped list of ALL tenants
/// (active + archived). Selecting one shows their Payment records newest first.
class TenantRentHistoryScreen extends StatelessWidget {
  const TenantRentHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return TenantPickerList(
      includeArchived: true,
      emptyText: 'No tenants with history.',
      searchHint: 'Search tenants',
      onPersonTap: (person) => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => _TenantPaymentHistoryScreen(person: person),
        ),
      ),
    );
  }
}

/// Detail screen showing a tenant's payment records newest first.
class _TenantPaymentHistoryScreen extends StatelessWidget {
  const _TenantPaymentHistoryScreen({required this.person});

  final Person person;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final payments = store.payments
        .where((p) => p.personId == person.id)
        .toList()
      ..sort((a, b) {
        // Sort by month descending, then by type (deposit first? just by ID)
        return b.month.compareTo(a.month);
      });

    return Scaffold(
      appBar: AppBar(title: Text(person.name)),
      body: payments.isEmpty
          ? const Center(child: Text('No payments recorded yet'))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                for (final payment in payments)
                  Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: Icon(
                        payment.type == PaymentType.deposit
                            ? Icons.account_balance_wallet_outlined
                            : Icons.payments_outlined,
                        color: payment.type == PaymentType.deposit
                            ? Colors.amber
                            : null,
                      ),
                      title: Text(formatMoneyShort(payment.amountPaid)),
                      subtitle: Text(
                          'Month ${payment.month} · ${payment.type.name}'),
                      trailing: Text(_typeLabel(payment.type)),
                    ),
                  ),
              ],
            ),
    );
  }

  String _typeLabel(PaymentType type) {
    switch (type) {
      case PaymentType.deposit:
        return 'Deposit';
      case PaymentType.rent:
        return 'Rent';
    }
  }
}