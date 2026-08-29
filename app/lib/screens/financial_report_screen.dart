import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

// ignore_for_file: unused_import, deprecated_member_use
import '../config.dart';
import '../navigation/routes.dart';
import '../services/expense_aggregation_service.dart';
import '../services/report_service.dart';
import '../services/store_scope.dart';
import '../utils/format.dart';

enum ReportScope { thisMonth, twelveMonths, yearly }
enum ChartType { line, bar }

class FinancialReportScreen extends StatefulWidget {
  const FinancialReportScreen({super.key});

  @override
  State<FinancialReportScreen> createState() => _FinancialReportScreenState();
}

class _FinancialReportScreenState extends State<FinancialReportScreen> {
  ReportScope _scope = ReportScope.thisMonth;
  String? _selectedFlatId;
  ChartType _chartType = ChartType.line;
  int _selectedYear = DateTime.now().year;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final flats = store.flats.where((f) => !f.archived).toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Scope selector
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
        // Flat filter
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
        if (_scope == ReportScope.twelveMonths) _TwelveMonthsChart(flatId: _selectedFlatId, chartType: _chartType, onToggle: () => setState(() => _chartType = _chartType == ChartType.line ? ChartType.bar : ChartType.line)),
        if (_scope == ReportScope.yearly) _YearlyChart(year: _selectedYear, flatId: _selectedFlatId, chartType: _chartType, onToggle: () => setState(() => _chartType = _chartType == ChartType.line ? ChartType.bar : ChartType.line)),
        const SizedBox(height: 24),
        // Quick links
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
    // Navigate to Finance screen - for now just navigate to Finance route
    // The FinanceScreen will handle initial tab via its DefaultTabController
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('This Month Breakdown', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        for (final flat in flats)
          Builder(builder: (context) {
            final income = ReportService.flatIncome(payments: store.payments, flatId: flat.id, month: month);
            final expense = ExpenseAggregationService.totalExpensesForFlat(
                flatId: flat.id, month: month, expenses: store.expenses, leaseChequeRecords: store.leaseChequeRecords);
            final net = income - expense;
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(flat.name, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Income: ${formatMoneyShort(income)}', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.green)),
                        Text('Expense: ${formatMoneyShort(expense)}', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.red)),
                        Text('Net: ${formatMoneyShort(net)}', style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700, color: net >= 0 ? Colors.green : Colors.red)),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }
}

class _TwelveMonthsChart extends StatelessWidget {
  const _TwelveMonthsChart({required this.flatId, required this.chartType, required this.onToggle});
  final String? flatId;
  final ChartType chartType;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final data = ReportService.trailing12Months(
      flatId: flatId,
      payments: store.payments,
      expenses: store.expenses,
      leaseChequeRecords: store.leaseChequeRecords,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Last 12 Months', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
            const Spacer(),
            SegmentedButton<ChartType>(
              segments: const [
                ButtonSegment(value: ChartType.line, label: Text('Line'), icon: Icon(Icons.show_chart, size: 16)),
                ButtonSegment(value: ChartType.bar, label: Text('Bar'), icon: Icon(Icons.bar_chart, size: 16)),
              ],
              selected: {chartType},
              onSelectionChanged: (s) => onToggle(),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 200,
          child: chartType == ChartType.line ? _LineChart(data: data, flatId: flatId) : _BarChart(data: data, flatId: flatId),
        ),
      ],
    );
  }
}

class _YearlyChart extends StatelessWidget {
  const _YearlyChart({required this.year, required this.flatId, required this.chartType, required this.onToggle});
  final int year;
  final String? flatId;
  final ChartType chartType;
  final VoidCallback onToggle;

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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Year $year', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
            const Spacer(),
            SegmentedButton<ChartType>(
              segments: const [
                ButtonSegment(value: ChartType.line, label: Text('Line'), icon: Icon(Icons.show_chart, size: 16)),
                ButtonSegment(value: ChartType.bar, label: Text('Bar'), icon: Icon(Icons.bar_chart, size: 16)),
              ],
              selected: {chartType},
              onSelectionChanged: (s) => onToggle(),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text('Income: ${formatMoneyShort(yearly.income)}  Expense: ${formatMoneyShort(yearly.expense)}  Net: ${formatMoneyShort(yearly.net)}',
            style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 12),
        SizedBox(
          height: 200,
          child: chartType == ChartType.line ? _LineChart(data: data, flatId: flatId) : _BarChart(data: data, flatId: flatId),
        ),
      ],
    );
  }
}

class _LineChart extends StatelessWidget {
  const _LineChart({required this.data, this.flatId});
  final List<({String month, double income, double expense, double net})> data;
  final String? flatId;

  @override
  Widget build(BuildContext context) {
    return LineChart(
      LineChartData(
        lineBarsData: [
          LineChartBarData(
            spots: [for (int i = 0; i < data.length; i++) FlSpot(i.toDouble(), data[i].income)],
            isCurved: true,
            color: Colors.green,
            barWidth: 2,
            dotData: const FlDotData(show: true),
          ),
          LineChartBarData(
            spots: [for (int i = 0; i < data.length; i++) FlSpot(i.toDouble(), data[i].expense)],
            isCurved: true,
            color: Colors.red,
            barWidth: 2,
            dotData: const FlDotData(show: true),
          ),
          LineChartBarData(
            spots: [for (int i = 0; i < data.length; i++) FlSpot(i.toDouble(), data[i].net)],
            isCurved: true,
            color: Colors.blue,
            barWidth: 2,
            dotData: const FlDotData(show: true),
          ),
        ],
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx < 0 || idx >= data.length) return const SizedBox.shrink();
                final month = data[idx].month.split('-')[1];
                return Text(month, style: Theme.of(context).textTheme.labelSmall);
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) => Text(
                value.toInt().toString(),
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        lineTouchData: LineTouchData(
          enabled: true,
          touchTooltipData: LineTouchTooltipData(),
        ),
      ),
    );
  }
}

class _BarChart extends StatelessWidget {
  const _BarChart({required this.data, this.flatId});
  final List<({String month, double income, double expense, double net})> data;
  final String? flatId;

  @override
  Widget build(BuildContext context) {
    return BarChart(
      BarChartData(
        barGroups: [
          for (int i = 0; i < data.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(toY: data[i].income, color: Colors.green, width: 6),
                BarChartRodData(toY: data[i].expense, color: Colors.red, width: 6),
                BarChartRodData(toY: data[i].net, color: Colors.blue, width: 6),
              ],
            ),
        ],
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx < 0 || idx >= data.length) return const SizedBox.shrink();
                final month = data[idx].month.split('-')[1];
                return Text(month, style: Theme.of(context).textTheme.labelSmall);
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) => Text(
                value.toInt().toString(),
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(),
        ),
      ),
    );
  }
}
