import 'package:flutter/material.dart';

import '../navigation/routes.dart';

/// Payments hub: two large entry buttons, one per payment type. Each pushes
/// its own screen; both write to the same ledger read by History and the
/// Dashboard.
class PaymentsScreen extends StatelessWidget {
  const PaymentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _EntryCard(
          icon: Icons.receipt_long_outlined,
          title: 'Flat Lease Payment',
          subtitle: 'Cheques paid to flat owners',
          onTap: () =>
              Navigator.pushNamed(context, Routes.paymentsFlatLease),
        ),
        const SizedBox(height: 12),
        _EntryCard(
          icon: Icons.payments_outlined,
          title: 'Tenant Rent Payment',
          subtitle: 'Rent collected from tenants',
          onTap: () =>
              Navigator.pushNamed(context, Routes.paymentsTenantRent),
        ),
      ],
    );
  }
}

class _EntryCard extends StatelessWidget {
  const _EntryCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
          child: Row(
            children: [
              Icon(icon, size: 36, color: theme.colorScheme.primary),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
