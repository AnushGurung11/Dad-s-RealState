import 'package:flutter/material.dart';

import 'cheque_payment_flat_screen.dart';
import 'expenses_screen.dart';
import 'financial_report_screen.dart';
import 'payment_history_screen.dart';
import 'tenant_rent_payment_screen.dart';

/// Finance tab group: consolidates Report | Cheque | Rent | Expenses | History
/// This is the ONLY nav destination for all financial screens.
class FinanceScreen extends StatelessWidget {
  const FinanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
      child: Column(
        children: [
          Material(
            color: Theme.of(context).colorScheme.surface,
            child: TabBar(
              isScrollable: true,
              labelColor: Theme.of(context).colorScheme.primary,
              unselectedLabelColor: Colors.grey,
              indicatorColor: Theme.of(context).colorScheme.primary,
              tabs: const [
                Tab(text: 'Report'),
                Tab(text: 'Cheque'),
                Tab(text: 'Rent'),
                Tab(text: 'Expenses'),
                Tab(text: 'History'),
              ],
            ),
          ),
          const Expanded(
            child: TabBarView(
              children: [
                FinancialReportScreen(),
                ChequePaymentFlatScreen(),
                TenantRentPaymentScreen(),
                ExpensesScreen(),
                PaymentHistoryScreen(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
