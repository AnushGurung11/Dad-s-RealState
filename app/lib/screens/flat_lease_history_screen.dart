import 'package:flutter/material.dart';

import '../models/flat.dart';
import '../services/store_scope.dart';
import '../utils/format.dart';

/// Flat Lease History: list all flats; tapping one shows its immutable
/// LeaseChequeRecord list newest first.
class FlatLeaseHistoryScreen extends StatelessWidget {
  const FlatLeaseHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final flats = [...store.flats];
    flats.sort((a, b) => a.name.compareTo(b.name));

    if (flats.isEmpty) {
      return const Center(child: Text('No flats yet.'));
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final flat in flats)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: const Icon(Icons.receipt_long_outlined),
              title: Text(flat.name),
              subtitle: const Text('Tap to view cheque records'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => _FlatLeaseRecordListScreen(flat: flat),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Detail screen for a single flat's cheque records.
class _FlatLeaseRecordListScreen extends StatelessWidget {
  const _FlatLeaseRecordListScreen({required this.flat});

  final Flat flat;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final records = store.leaseChequeRecords
        .where((r) => r.flatId == flat.id)
        .toList()
      ..sort((a, b) => b.paidDate.compareTo(a.paidDate)); // newest first

    return Scaffold(
      appBar: AppBar(title: Text(flat.name)),
      body: records.isEmpty
          ? const Center(child: Text('No payments recorded yet'))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                for (final record in records)
                  Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: const Icon(Icons.receipt_long),
                      title: Text(formatMoneyShort(record.amount)),
                      subtitle: Text(
                          'Paid ${_dateText(record.paidDate)} · Due ${_dateText(record.dueDate)}'),
                      trailing: Text(_monthText(record.month)),
                      isThreeLine: true,
                    ),
                  ),
              ],
            ),
    );
  }

  String _dateText(DateTime date) => '${date.year}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  String _monthText(String month) => month.replaceFirst('-', '-');
}