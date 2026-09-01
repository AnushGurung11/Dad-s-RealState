import 'package:flutter/material.dart';

import '../models/payment.dart';
import '../models/person.dart';
import '../services/store_scope.dart';
import '../services/transaction_edit_service.dart';
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
class _TenantPaymentHistoryScreen extends StatefulWidget {
  const _TenantPaymentHistoryScreen({required this.person});

  final Person person;

  @override
  State<_TenantPaymentHistoryScreen> createState() =>
      _TenantPaymentHistoryScreenState();
}

class _TenantPaymentHistoryScreenState
    extends State<_TenantPaymentHistoryScreen> {
  void _refresh() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final payments = store.payments
        .where((p) => p.personId == widget.person.id)
        .toList()
      ..sort((a, b) => b.month.compareTo(a.month));

    return Scaffold(
      appBar: AppBar(title: Text(widget.person.name)),
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
                      trailing: PopupMenuButton<String>(
                        onSelected: (action) {
                          if (action == 'edit') {
                            _showEditDialog(payment);
                          } else if (action == 'delete') {
                            _confirmDelete(payment);
                          }
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 'edit', child: Text('Edit')),
                          PopupMenuItem(value: 'delete', child: Text('Delete')),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  void _showEditDialog(Payment payment) {
    final amountController =
        TextEditingController(text: payment.amountPaid.toString());
    final descController =
        TextEditingController(text: payment.description ?? '');
    final methodController =
        TextEditingController(text: payment.paymentMethod ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit payment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: amountController,
              decoration: const InputDecoration(
                labelText: 'Amount (AED)',
                border: OutlineInputBorder(),
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: descController,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: methodController,
              decoration: const InputDecoration(
                labelText: 'Payment method (optional)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final amount = double.tryParse(amountController.text);
              Navigator.pop(ctx, {
                'amount': amount,
                'description': descController.text.trim(),
                'paymentMethod': methodController.text.trim(),
              });
            },
            child: const Text('Save'),
          ),
        ],
      ),
    ).then((result) {
      if (result == null || !mounted) return;
      final amount = result['amount'] as double?;
      if (amount == null || amount <= 0) return;
      try {
        final service = TransactionEditService(StoreScope.of(context));
        final desc = result['description'] as String;
        final method = result['paymentMethod'] as String;
        service.editPayment(
          payment.id,
          amount: amount,
          description: desc.isNotEmpty ? desc : null,
          paymentMethod: method.isNotEmpty ? method : null,
        );
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(content: Text('Payment updated')));
        _refresh();
      } catch (e) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    });
  }

  void _confirmDelete(Payment payment) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete payment?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              try {
                TransactionEditService(StoreScope.of(context))
                    .deletePayment(payment.id);
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(
                      const SnackBar(content: Text('Payment deleted')));
                _refresh();
              } catch (e) {
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(SnackBar(content: Text('Failed: $e')));
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
