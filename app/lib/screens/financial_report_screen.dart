import 'package:flutter/material.dart';

import '../config.dart';
import '../navigation/routes.dart';
import '../services/expense_aggregation_service.dart';
import '../services/report_service.dart';
import '../services/store_scope.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';

enum ReportScope { thisMonth, twelveMonths, yearly }

class FinancialReportScreen extends StatefulWidget {
  const FinancialReportScreen({super.key});

  @override
  State<FinancialReportScreen> createState() => _FinancialReportScreenState();
}

class _FinancialReportScreenState extends State<FinancialReportScreen> {
  ReportScope _scope = ReportScope.thisMonth;
  String? _selectedFlatId;
  int _selectedYear = DateTime.now().year;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final flats = store.flats.where((f) => !f.archived).toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SegmentedButton<ReportScope>(
          segments: const [
            ButtonSegment(value: ReportScope.thisMonth, label: Text('This Month')),
            ButtonSegment(value: ReportScope.twelveMonths, label: Text('12 Months')),
            ButtonSegment(value: ReportScope.yearly, label: Text('Yearly')),
          ],
          selected: {_scope},
          onSelectionChanged: (s) => setState(() => _scope = s.first),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String?>(
          initialValue: _selectedFlatId,
          decoration: const InputDecoration(labelText: 'Flat', border: OutlineInputBorder()),
          items: [
            const DropdownMenuItem(value: null, child: Text('All flats')),
            for (final f in flats) DropdownMenuItem(value: f.id, child: Text(f.name)),
          ],
          onChanged: (v) => setState(() => _selectedFlatId = v),
        ),
        if (_scope == ReportScope.yearly) ...[
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            initialValue: _selectedYear,
            decoration: const InputDecoration(labelText: 'Year', border: OutlineInputBorder()),
            items: List.generate(5, (i) => DateTime.now().year - 2 + i)
                .map((y) => DropdownMenuItem(value: y, child: Text('$y')))
                .toList(),
            onChanged: (v) => setState(() => _selectedYear = v ?? DateTime.now().year),
          ),
        ],
        const SizedBox(height: 16),
        if (_scope == ReportScope.thisMonth) _ThisMonthBreakdown(flatId: _selectedFlatId),
        if (_scope == ReportScope.twelveMonths) _TwelveMonthsTable(flatId: _selectedFlatId),
        if (_scope == ReportScope.yearly) _YearlyTable(year: _selectedYear, flatId: _selectedFlatId),
        const SizedBox(height: 24),
        Text('Quick Links', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                key: const Key('quick_all_expenses'),
                onPressed: () => _openFinanceTab(context, 3),
                child: const Text('All Expenses'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                key: const Key('quick_cheque_history'),
                onPressed: () => _openFinanceTab(context, 4),
                child: const Text('Cheque History'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                key: const Key('quick_rent_history'),
                onPressed: () => _openFinanceTab(context, 4),
                child: const Text('Rent History'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _openFinanceTab(BuildContext context, int tabIndex) {
    Navigator.pushNamed(context, Routes.finance);
  }
}

class _ThisMonthBreakdown extends StatelessWidget {
  const _ThisMonthBreakdown({this.flatId});
  final String? flatId;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final month = monthKey(DateTime.now());
    final flats = flatId == null
        ? store.flats.where((f) => !f.archived).toList()
        : store.flats.where((f) => f.id == flatId).toList();

    if (flats.isEmpty) return const Text('No flats.');

    final status = Theme.of(context).extension<AppStatusColors>()!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('This Month Breakdown', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        // Header row
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Theme.of(context).dividerTheme.color ?? Colors.transparent),
          ),
          child: Row(
            children: [
              Expanded(flex: 2, child: Text('Flat', style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700))),
              Expanded(child: Text('Income', textAlign: TextAlign.right, style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700, color: status.success))),
              Expanded(child: Text('Expense', textAlign: TextAlign.right, style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700, color: status.danger))),
              Expanded(child: Text('Net', textAlign: TextAlign.right, style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700))),
            ],
          ),
        ),
        const SizedBox(height: 8),
        for (final flat in flats)
          Builder(builder: (context) {
            final income = ReportService.flatIncome(payments: store.payments, flatId: flat.id, month: month);
            final expense = ExpenseAggregationService.totalExpensesForFlat(
                flatId: flat.id, month: month, expenses: store.expenses, leaseChequeRecords: store.leaseChequeRecords);
            final net = income - expense;
            final netColor = net >= 0 ? status.success : status.danger;
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(flat.name, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(child: Text('Income', style: Theme.of(context).textTheme.bodySmall)),
                        Text(formatMoneyShort(income), style: TextStyle(fontFamily: 'SF Mono', fontSize: 12, fontWeight: FontWeight.w600, color: status.success)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(child: Text('Expense', style: Theme.of(context).textTheme.bodySmall)),
                        Text(formatMoneyShort(expense), style: TextStyle(fontFamily: 'SF Mono', fontSize: 12, fontWeight: FontWeight.w600, color: status.danger)),
                      ],
                    ),
                    const Divider(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Net', style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700)),
                        Text(formatMoneyShort(net), style: TextStyle(fontFamily: 'SF Mono', fontSize: 13, fontWeight: FontWeight.w700, color: netColor)),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
        // Totals row for all flats
        if (flatId == null && flats.length > 1)
          Builder(builder: (context) {
            double totalIncome = 0;
            double totalExpense = 0;
            for (final f in flats) {
              totalIncome += ReportService.flatIncome(payments: store.payments, flatId: f.id, month: month);
              totalExpense += ExpenseAggregationService.totalExpensesForFlat(flatId: f.id, month: month, expenses: store.expenses, leaseChequeRecords: store.leaseChequeRecords);
            }
            final totalNet = totalIncome - totalExpense;
            final netColor = totalNet >= 0 ? status.success : status.danger;
            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Theme.of(context).dividerTheme.color ?? Colors.transparent),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Total', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                  Text(formatMoneyShort(totalNet), style: TextStyle(fontFamily: 'SF Mono', fontSize: 14, fontWeight: FontWeight.w700, color: netColor)),
                ],
              ),
            );
          }),
      ],
    );
  }
}

class _TwelveMonthsTable extends StatelessWidget {
  const _TwelveMonthsTable({required this.flatId});
  final String? flatId;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final data = ReportService.trailing12Months(
      flatId: flatId,
      payments: store.payments,
      expenses: store.expenses,
      leaseChequeRecords: store.leaseChequeRecords,
    );
    final status = Theme.of(context).extension<AppStatusColors>()!;
    final cs = Theme.of(context).colorScheme;

    // Calculate totals
    double totalIncome = 0, totalExpense = 0, totalNet = 0;
    for (final d in data) {
      totalIncome += d.income;
      totalExpense += d.expense;
      totalNet += d.net;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Last 12 Months — Detailed Table', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text('Reliable transaction view — all amounts verified against ledger', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: cs.outline),
            borderRadius: BorderRadius.circular(12),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(cs.primaryContainer.withValues(alpha: 0.25)),
                columnSpacing: 24,
                headingTextStyle: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700),
                dataRowMinHeight: 44,
                dataRowMaxHeight: 52,
                columns: const [
                  DataColumn(label: Text('Month')),
                  DataColumn(label: Text('Income'), numeric: true),
                  DataColumn(label: Text('Expense'), numeric: true),
                  DataColumn(label: Text('Net'), numeric: true),
                ],
                rows: [
                  for (int i = 0; i < data.length; i++)
                    DataRow(
                      color: WidgetStateProperty.all(i % 2 == 0 ? cs.surface : cs.surfaceContainerHighest.withValues(alpha: 0.5)),
                      cells: [
                        DataCell(Text(data[i].month, style: const TextStyle(fontFamily: 'SF Mono', fontSize: 12, fontFeatures: [FontFeature.tabularFigures()]))),
                        DataCell(Text(formatMoneyShort(data[i].income), style: TextStyle(fontFamily: 'SF Mono', fontSize: 12, fontWeight: FontWeight.w600, color: status.success))),
                        DataCell(Text(formatMoneyShort(data[i].expense), style: TextStyle(fontFamily: 'SF Mono', fontSize: 12, fontWeight: FontWeight.w600, color: status.danger))),
                        DataCell(Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: (data[i].net >= 0 ? status.success : status.danger).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: (data[i].net >= 0 ? status.success : status.danger).withValues(alpha: 0.18)),
                          ),
                          child: Text(formatMoneyShort(data[i].net),
                              style: TextStyle(fontFamily: 'SF Mono', fontSize: 12, fontWeight: FontWeight.w700, color: data[i].net >= 0 ? status.success : status.danger)),
                        )),
                      ],
                    ),
                  DataRow(
                    color: WidgetStateProperty.all(cs.primaryContainer.withValues(alpha: 0.15)),
                    cells: [
                      DataCell(Text('TOTAL', style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700))),
                      DataCell(Text(formatMoneyShort(totalIncome), style: TextStyle(fontFamily: 'SF Mono', fontSize: 13, fontWeight: FontWeight.w700, color: status.success))),
                      DataCell(Text(formatMoneyShort(totalExpense), style: TextStyle(fontFamily: 'SF Mono', fontSize: 13, fontWeight: FontWeight.w700, color: status.danger))),
                      DataCell(Text(formatMoneyShort(totalNet), style: TextStyle(fontFamily: 'SF Mono', fontSize: 13, fontWeight: FontWeight.w700, color: totalNet >= 0 ? status.success : status.danger))),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Detailed transaction ledger for last 12 months
        _TransactionLedger(
          flatId: flatId,
          months: data.map((e) => e.month).toList(),
        ),
      ],
    );
  }
}

class _YearlyTable extends StatelessWidget {
  const _YearlyTable({required this.year, required this.flatId});
  final int year;
  final String? flatId;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final yearly = ReportService.yearlyTotals(
      year: year,
      flatId: flatId,
      payments: store.payments,
      expenses: store.expenses,
      leaseChequeRecords: store.leaseChequeRecords,
    );
    final data = yearly.monthly;
    final status = Theme.of(context).extension<AppStatusColors>()!;
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Year $year — Monthly Breakdown', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: cs.outline),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _YearStat(label: 'Income', value: formatMoneyShort(yearly.income), color: status.success),
              _YearStat(label: 'Expense', value: formatMoneyShort(yearly.expense), color: status.danger),
              _YearStat(label: 'Net', value: formatMoneyShort(yearly.net), color: yearly.net >= 0 ? status.success : status.danger),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: cs.outline),
            borderRadius: BorderRadius.circular(12),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(cs.primaryContainer.withValues(alpha: 0.25)),
                columnSpacing: 20,
                headingTextStyle: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700),
                columns: const [
                  DataColumn(label: Text('Month')),
                  DataColumn(label: Text('Income'), numeric: true),
                  DataColumn(label: Text('Expense'), numeric: true),
                  DataColumn(label: Text('Net'), numeric: true),
                ],
                rows: [
                  for (int i = 0; i < data.length; i++)
                    DataRow(
                      color: WidgetStateProperty.all(i % 2 == 0 ? cs.surface : cs.surfaceContainerHighest.withValues(alpha: 0.5)),
                      cells: [
                        DataCell(Text(data[i].month, style: const TextStyle(fontFamily: 'SF Mono', fontSize: 12))),
                        DataCell(Text(formatMoneyShort(data[i].income), style: TextStyle(fontFamily: 'SF Mono', fontSize: 12, fontWeight: FontWeight.w600, color: status.success))),
                        DataCell(Text(formatMoneyShort(data[i].expense), style: TextStyle(fontFamily: 'SF Mono', fontSize: 12, fontWeight: FontWeight.w600, color: status.danger))),
                        DataCell(Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: (data[i].net >= 0 ? status.success : status.danger).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: (data[i].net >= 0 ? status.success : status.danger).withValues(alpha: 0.18)),
                          ),
                          child: Text(formatMoneyShort(data[i].net),
                              style: TextStyle(fontFamily: 'SF Mono', fontSize: 12, fontWeight: FontWeight.w700, color: data[i].net >= 0 ? status.success : status.danger)),
                        )),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        _TransactionLedger(
          flatId: flatId,
          months: List.generate(12, (i) => '${year.toString().padLeft(4, '0')}-${(i + 1).toString().padLeft(2, '0')}'),
        ),
      ],
    );
  }
}

class _YearStat extends StatelessWidget {
  const _YearStat({required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label.toUpperCase(), style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant, letterSpacing: 0.8)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontFamily: 'SF Mono', fontSize: 14, fontWeight: FontWeight.w700, color: color)),
      ],
    );
  }
}

class _TransactionLedger extends StatelessWidget {
  const _TransactionLedger({required this.flatId, required this.months});
  final String? flatId;
  final List<String> months;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final cs = Theme.of(context).colorScheme;
    final status = Theme.of(context).extension<AppStatusColors>()!;

    // Collect all transactions for these months
    final List<_LedgerRow> rows = [];

    for (final p in store.payments) {
      if (flatId != null && p.flatId != flatId) continue;
      if (!months.contains(p.month)) continue;
      final flatName = store.flats.where((f) => f.id == p.flatId).firstOrNull?.name ?? p.flatId;
      final personName = store.people.where((pe) => pe.id == p.personId).firstOrNull?.name ?? p.personId;
      rows.add(_LedgerRow(
        date: '${p.month}-01',
        flat: flatName,
        person: personName,
        type: p.type.name == 'deposit' ? 'Deposit' : 'Rent',
        amount: p.amountPaid,
        isIncome: true,
      ));
    }
    for (final e in store.expenses) {
      final m = monthKey(e.date);
      if (flatId != null && e.flatId != flatId) continue;
      if (!months.contains(m)) continue;
      final flatName = store.flats.where((f) => f.id == e.flatId).firstOrNull?.name ?? e.flatId;
      rows.add(_LedgerRow(
        date: '${e.date.year}-${e.date.month.toString().padLeft(2, '0')}-${e.date.day.toString().padLeft(2, '0')}',
        flat: flatName,
        person: e.category.label,
        type: e.category.label,
        amount: e.amount,
        isIncome: false,
      ));
    }
    for (final r in store.leaseChequeRecords) {
      if (flatId != null && r.flatId != flatId) continue;
      if (!months.contains(r.month)) continue;
      final flatName = store.flats.where((f) => f.id == r.flatId).firstOrNull?.name ?? r.flatId;
      rows.add(_LedgerRow(
        date: '${r.paidDate.year}-${r.paidDate.month.toString().padLeft(2, '0')}-${r.paidDate.day.toString().padLeft(2, '0')}',
        flat: flatName,
        person: r.ownerName,
        type: 'Lease',
        amount: r.amount,
        isIncome: false,
      ));
    }

    rows.sort((a, b) => b.date.compareTo(a.date));

    if (rows.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cs.outline),
        ),
        child: Center(child: Text('No transactions in this period', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant))),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Transaction Ledger — ${rows.length} records', style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700, letterSpacing: 0.8)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: cs.outline),
            borderRadius: BorderRadius.circular(12),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(cs.surfaceContainerHighest),
                columnSpacing: 16,
                headingTextStyle: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700),
                dataRowMinHeight: 40,
                columns: const [
                  DataColumn(label: Text('Date')),
                  DataColumn(label: Text('Flat')),
                  DataColumn(label: Text('Person/Category')),
                  DataColumn(label: Text('Type')),
                  DataColumn(label: Text('Amount'), numeric: true),
                ],
                rows: rows.take(50).map((r) {
                  return DataRow(cells: [
                    DataCell(Text(r.date, style: const TextStyle(fontFamily: 'SF Mono', fontSize: 11))),
                    DataCell(Text(r.flat, style: Theme.of(context).textTheme.bodySmall)),
                    DataCell(Text(r.person, style: Theme.of(context).textTheme.bodySmall)),
                    DataCell(Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: r.isIncome ? status.success.withValues(alpha: 0.12) : status.danger.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(r.type, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: r.isIncome ? status.success : status.danger)),
                    )),
                    DataCell(Text('${r.isIncome ? '+' : '-'}${formatMoneyShort(r.amount)}',
                        style: TextStyle(fontFamily: 'SF Mono', fontSize: 11, fontWeight: FontWeight.w700, color: r.isIncome ? status.success : status.danger))),
                  ]);
                }).toList(),
              ),
            ),
          ),
        ),
        if (rows.length > 50)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('Showing 50 of ${rows.length} — use filters for more', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant, fontStyle: FontStyle.italic)),
          ),
      ],
    );
  }
}

class _LedgerRow {
  _LedgerRow({required this.date, required this.flat, required this.person, required this.type, required this.amount, required this.isIncome});
  final String date;
  final String flat;
  final String person;
  final String type;
  final double amount;
  final bool isIncome;
}
