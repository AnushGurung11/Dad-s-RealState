// ignore_for_file: unused_field, unused_element, curly_braces_in_flow_control_structures, unused_local_variable
import 'dart:io';

import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';

import '../config.dart';
import '../models/bed.dart';
import '../models/expense.dart';
import '../models/flat.dart';
import '../models/lease_cheque_record.dart';
import '../models/lease_termination_record.dart';
import '../models/lease_cheque_setting.dart';
import '../models/payment.dart' hide PaymentStatus, PaymentType;
import '../models/person.dart';
import '../services/report_service.dart';

/// Service for exporting all data to a polished, color-highlighted Excel workbook.
class ExcelExportService {
  ExcelExportService({
    required this.flats,
    required this.beds,
    required this.people,
    required this.payments,
    required this.expenses,
    required this.leaseChequeSettings,
    required this.leaseChequeRecords,
    required this.terminations,
    this.getDocumentsDirectory,
  });

  final List<Flat> flats;
  final List<Bed> beds;
  final List<Person> people;
  final List<Payment> payments;
  final List<Expense> expenses;
  final List<LeaseChequeSetting> leaseChequeSettings;
  final List<LeaseChequeRecord> leaseChequeRecords;
  final List<LeaseTerminationRecord> terminations;

  final Future<Directory> Function()? getDocumentsDirectory;

  // â”€â”€ Brand Colors (per light theme spec, polished for print) â”€â”€
  static const String _accentHex = '#3B6FD4';
  static const String _accentLightHex = '#EFF4FF';
  static const String _accentBorderHex = '#BFDBFE';
  static const String _textDarkHex = '#0C0C12';
  static const String _gridBorderHex = '#E2E8F0';
  static const String _altRowHex = '#F8FAFC';
  static const String _successBg = '#DCFCE7';
  static const String _successText = '#166534';
  static const String _dangerBg = '#FEE2E2';
  static const String _dangerText = '#991B1B';
  static const String _warnBg = '#FEF3C7';
  static const String _warnText = '#92400E';
  static const String _neutralBg = '#F1F5F9';
  static const String _white = '#FFFFFF';

  CellStyle get _headerStyle => CellStyle(
        bold: true,
        fontSize: 11,
        fontColorHex: _white,
        backgroundColorHex: _accentHex,
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
        leftBorder: Border(borderStyle: BorderStyle.Thin, borderColorHex: _accentHex),
        rightBorder: Border(borderStyle: BorderStyle.Thin, borderColorHex: _accentHex),
        topBorder: Border(borderStyle: BorderStyle.Thin, borderColorHex: _accentHex),
        bottomBorder: Border(borderStyle: BorderStyle.Thin, borderColorHex: _accentHex),
      );

  CellStyle get _subHeaderStyle => CellStyle(
        bold: true,
        fontSize: 11,
        fontColorHex: _textDarkHex,
        backgroundColorHex: _accentLightHex,
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
      );

  CellStyle _dataStyle({bool alt = false, String? bg, String? textColor}) => CellStyle(
        fontSize: 10,
        fontColorHex: textColor ?? _textDarkHex,
        backgroundColorHex: bg ?? (alt ? _altRowHex : _white),
        horizontalAlign: HorizontalAlign.Left,
        verticalAlign: VerticalAlign.Center,
        leftBorder: Border(borderStyle: BorderStyle.Thin, borderColorHex: _gridBorderHex),
        rightBorder: Border(borderStyle: BorderStyle.Thin, borderColorHex: _gridBorderHex),
        topBorder: Border(borderStyle: BorderStyle.Thin, borderColorHex: _gridBorderHex),
        bottomBorder: Border(borderStyle: BorderStyle.Thin, borderColorHex: _gridBorderHex),
      );

  CellStyle get _currencyStyle => _dataStyle();
  CellStyle get _successStyle => _dataStyle(bg: _successBg, textColor: _successText);
  CellStyle get _dangerStyle => _dataStyle(bg: _dangerBg, textColor: _dangerText);
  CellStyle get _neutralStyle => _dataStyle(bg: _neutralBg);

  CellStyle _netStyle(double net, bool alt) {
    if (net > 0) return _dataStyle(alt: alt, bg: _successBg, textColor: _successText);
    if (net < 0) return _dataStyle(alt: alt, bg: _dangerBg, textColor: _dangerText);
    return _dataStyle(alt: alt, bg: _neutralBg);
  }

  void _styleHeaderRow(Sheet sheet, int columnCount) {
    for (var col = 0; col < columnCount; col++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0));
      cell.cellStyle = _headerStyle;
    }
  }

  void _styleDataRow(Sheet sheet, int rowIndex, int columnCount, {bool alt = false, List<CellStyle?>? perColumn}) {
    for (var col = 0; col < columnCount; col++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: rowIndex));
      if (perColumn != null && col < perColumn.length && perColumn[col] != null) {
        cell.cellStyle = perColumn[col]!;
      } else {
        cell.cellStyle = _dataStyle(alt: alt);
      }
    }
  }

  void _autoWidths(Sheet sheet, List<double> widths) {
    for (var i = 0; i < widths.length; i++) {
      sheet.setColWidth(i, widths[i]);
    }
  }

  Future<File> exportToExcel() async {
    final excel = Excel.createExcel();
    excel.delete('Sheet1');

    _addReadMeSheet(excel);
    _addSummarySheet(excel);
    _addTenantsSheet(excel);
    _addFlatsAndBedsSheet(excel);
    _addFinancialReportSheet(excel);
    _addChequePaymentHistorySheet(excel);
    _addTenantRentHistorySheet(excel);
    _addExpensesSheet(excel);

    final docsDir = getDocumentsDirectory != null ? await getDocumentsDirectory!() : await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').replaceAll('.', '-');
    final file = File('${docsDir.path}/lucky-export-$timestamp.xlsx');
    final bytes = excel.encode();
    if (bytes == null) throw StateError('Failed to encode Excel file');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  void _addReadMeSheet(Excel excel) {
    final sheet = excel['Read me'];
    sheet.setColWidth(0, 90.0);
    final titleStyle = CellStyle(bold: true, fontSize: 14, fontColorHex: _accentHex, backgroundColorHex: _accentLightHex, horizontalAlign: HorizontalAlign.Left);
    final bodyStyle = CellStyle(fontSize: 10, fontColorHex: _textDarkHex, backgroundColorHex: _white, horizontalAlign: HorizontalAlign.Left, verticalAlign: VerticalAlign.Center);
    final warnStyle = CellStyle(fontSize: 10, fontColorHex: _warnText, backgroundColorHex: _warnBg, bold: true, horizontalAlign: HorizontalAlign.Left);

    sheet.appendRow(['LUCKY â€” Financial Export']);
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0)).cellStyle = titleStyle;
    sheet.merge(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0), CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0));
    sheet.appendRow(['Generated: ${_formatDateTime(DateTime.now())}  â€¢  App: LUCKY  â€¢  Currency: AED']);
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1)).cellStyle = bodyStyle;
    sheet.appendRow(['']);
    sheet.appendRow(['How to use â€”']);
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 3)).cellStyle = _subHeaderStyle;
    sheet.appendRow(['• This file is a point-in-time export for viewing/record-keeping only and is never re-imported — edits here have no effect.']);
    sheet.appendRow(['â€¢ Header row (blue) is frozen â€” scroll to keep titles visible. Use filters on headers.']);
    sheet.appendRow(['â€¢ Green = income/profit, Red = expense/loss, Amber = warning/partial, Blue = accent.']);
    sheet.appendRow(['â€¢ Currency amounts are in AED. Dates are YYYY-MM-DD.']);
    sheet.appendRow(['â€¢ Sheets: Summary | Tenants | Flats & Beds | Financial Report | Cheque History | Rent History | Expenses']);
    for (var r = 4; r <= 8; r++) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: r)).cellStyle = bodyStyle;
    }
    sheet.appendRow(['']);
    sheet.appendRow(['Note: Any manual edits are for your records only. To change data, use the LUCKY app.']);
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 10)).cellStyle = warnStyle;

    // Set row heights
    for (var r = 0; r < 11; r++) {
    }
  }

  void _addSummarySheet(Excel excel) {
    final sheet = excel['Summary'];
    sheet.appendRow(['Metric', 'Value', 'Notes']);
    _styleHeaderRow(sheet, 3);
    _autoWidths(sheet, [28.0, 22.0, 40.0]);

    final totalIncome = payments.fold<double>(0, (s, p) => s + p.amountPaid);
    final totalExpense = expenses.fold<double>(0, (s, e) => s + e.amount) + leaseChequeRecords.fold<double>(0, (s, r) => s + r.amount);
    final totalNet = totalIncome - totalExpense;
    final flatCount = flats.where((f) => !f.archived).length;
    final archivedCount = flats.where((f) => f.archived).length;
    final tenantActive = people.where((p) => p.status == PersonStatus.active).length;
    final tenantArchived = people.where((p) => p.status != PersonStatus.active).length;

    final rows = [
      ['Active Flats', flatCount, 'Currently managed'],
      ['Archived Flats', archivedCount, 'Retired from grid'],
      ['Active Tenants', tenantActive, 'Assigned + unassigned'],
      ['Archived Tenants', tenantArchived, 'Ended / absconded'],
      ['Total Income (all time)', _fmtAED(totalIncome), 'Rent + Deposits'],
      ['Total Expense (all time)', _fmtAED(totalExpense), 'Expenses + Lease Cheques'],
      ['Net (all time)', _fmtAED(totalNet), 'Income - Expense'],
      ['Beds Total', beds.length, '5-20 per flat'],
      ['Generated', _formatDateTime(DateTime.now()), 'Local device time'],
    ];

    for (var i = 0; i < rows.length; i++) {
      final alt = i % 2 == 1;
      sheet.appendRow(rows[i]);
      final rowIdx = i + 1;
      final isNet = i == 6;
      final styles = isNet
          ? [null, _netStyle(totalNet, alt), null]
          : [null, null, null];
      // Apply per-row styling
      for (var c = 0; c < 3; c++) {
        final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: rowIdx));
        if (c == 1 && isNet) {
          cell.cellStyle = _netStyle(totalNet, alt);
        } else if (c == 0) {
          cell.cellStyle = CellStyle(bold: true, fontSize: 10, backgroundColorHex: alt ? _altRowHex : _white, fontColorHex: _textDarkHex);
        } else {
          cell.cellStyle = _dataStyle(alt: alt);
        }
        // Add borders
        cell.cellStyle = (cell.cellStyle ?? _dataStyle(alt: alt)).copyWith(
          leftBorderVal: Border(borderStyle: BorderStyle.Thin, borderColorHex: _gridBorderHex),
          rightBorderVal: Border(borderStyle: BorderStyle.Thin, borderColorHex: _gridBorderHex),
          topBorderVal: Border(borderStyle: BorderStyle.Thin, borderColorHex: _gridBorderHex),
          bottomBorderVal: Border(borderStyle: BorderStyle.Thin, borderColorHex: _gridBorderHex),
        );
      }
    }
    // Header row height
  }

  void _addTenantsSheet(Excel excel) {
    final sheet = excel['Tenants'];
    sheet.appendRow(['Name', 'Contact', 'Workplace', 'Flat', 'Bed', 'Status', 'Join Date', 'Vacated Date', 'Monthly Rent (AED)', 'Deposit (AED)']);
    _styleHeaderRow(sheet, 10);
    _autoWidths(sheet, [22.0, 18.0, 20.0, 16.0, 12.0, 12.0, 14.0, 14.0, 16.0, 16.0]);

    final flatMap = {for (var f in flats) f.id: f};
    final bedMap = {for (var b in beds) b.id: b};

    for (var i = 0; i < people.length; i++) {
      final person = people[i];
      final flat = person.flatId != null ? flatMap[person.flatId!] : null;
      final bed = person.bedId != null ? bedMap[person.bedId!] : null;
      final alt = i % 2 == 1;

      // Status color
      String statusBg;
      String statusText;
      switch (person.status) {
        case PersonStatus.active:
          statusBg = _successBg;
          statusText = _successText;
          break;
        case PersonStatus.archived:
          statusBg = _neutralBg;
          statusText = _textDarkHex;
          break;
        case PersonStatus.absconded:
          statusBg = _dangerBg;
          statusText = _dangerText;
          break;
      }

      sheet.appendRow([
        person.name,
        person.contact,
        person.workplaceOrInfo ?? '',
        flat?.name ?? '',
        bed?.label ?? '',
        person.status.name,
        person.joinDate != null ? _formatDate(person.joinDate!) : '',
        person.vacatedDate != null ? _formatDate(person.vacatedDate!) : '',
        person.monthlyRent ?? 0,
        person.depositAmount ?? 0,
      ]);
      final rowIdx = i + 1;
      _styleDataRow(sheet, rowIdx, 10, alt: alt);
      // Highlight status cell
      final statusCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: rowIdx));
      statusCell.cellStyle = CellStyle(
        fontSize: 10,
        bold: true,
        fontColorHex: statusText,
        backgroundColorHex: statusBg,
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
        leftBorder: Border(borderStyle: BorderStyle.Thin, borderColorHex: _gridBorderHex),
        rightBorder: Border(borderStyle: BorderStyle.Thin, borderColorHex: _gridBorderHex),
        topBorder: Border(borderStyle: BorderStyle.Thin, borderColorHex: _gridBorderHex),
        bottomBorder: Border(borderStyle: BorderStyle.Thin, borderColorHex: _gridBorderHex),
      );
      // Currency cells right aligned with tabular feel
      for (var c in [8, 9]) {
        final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: rowIdx));
        cell.cellStyle = _dataStyle(alt: alt).copyWith(horizontalAlignVal: HorizontalAlign.Right);
      }
    }
  }

  void _addFlatsAndBedsSheet(Excel excel) {
    final sheet = excel['Flats & Beds'];
    sheet.appendRow(['Flat Name', 'Address', 'Registered Date', 'Bed Label', 'Occupant', 'Default Monthly Rent', 'Status']);
    _styleHeaderRow(sheet, 7);
    _autoWidths(sheet, [20.0, 30.0, 16.0, 12.0, 20.0, 16.0, 12.0]);

    final personMap = {for (var p in people) p.id: p};
    int row = 1;
    final allRows = <List<dynamic>>[];
    for (final flat in flats) {
      final flatBeds = beds.where((b) => b.flatId == flat.id).toList();
      if (flatBeds.isEmpty) {
        allRows.add([flat.name, flat.address, flat.registeredDate != null ? _formatDate(flat.registeredDate!) : '', '', '', '', flat.archived ? 'Archived' : 'Active']);
      } else {
        for (final bed in flatBeds) {
          final occupant = bed.tenantId != null ? personMap[bed.tenantId!] : null;
          allRows.add([flat.name, flat.address, flat.registeredDate != null ? _formatDate(flat.registeredDate!) : '', bed.label, occupant?.name ?? 'Vacant', bed.defaultMonthlyRent, flat.archived ? 'Archived' : 'Active']);
        }
      }
    }
    for (var i = 0; i < allRows.length; i++) {
      sheet.appendRow(allRows[i]);
      final alt = i % 2 == 1;
      _styleDataRow(sheet, row, 7, alt: alt);
      // Vacant highlight
      final occupantVal = allRows[i][4] as String;
      if (occupantVal == 'Vacant') {
        final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row));
        cell.cellStyle = _dataStyle(alt: alt, bg: _warnBg, textColor: _warnText).copyWith(horizontalAlignVal: HorizontalAlign.Center);
      }
      // Status
      final statusVal = allRows[i][6] as String;
      final statusCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: row));
      if (statusVal == 'Archived') {
        statusCell.cellStyle = _dataStyle(alt: alt, bg: _neutralBg).copyWith(horizontalAlignVal: HorizontalAlign.Center);
      } else {
        statusCell.cellStyle = _dataStyle(alt: alt, bg: _successBg, textColor: _successText).copyWith(horizontalAlignVal: HorizontalAlign.Center);
      }
      // Currency
      final rentCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: row));
      rentCell.cellStyle = _dataStyle(alt: alt).copyWith(horizontalAlignVal: HorizontalAlign.Right);
      row++;
    }
  }

  void _addFinancialReportSheet(Excel excel) {
    final sheet = excel['Financial Report'];
    sheet.appendRow(['Flat', 'Month', 'Income (AED)', 'Expenses (AED)', 'Net (AED)', 'Remarks']);
    _styleHeaderRow(sheet, 6);
    _autoWidths(sheet, [18.0, 12.0, 16.0, 16.0, 16.0, 22.0]);

    final months = <String>{};
    for (final p in payments) months.add(p.month);
    for (final e in expenses) months.add(monthKey(e.date));
    final sortedMonths = months.toList()..sort();

    int row = 1;
    for (final flat in flats) {
      for (final month in sortedMonths) {
        final summary = ReportService.flatSummary(payments: payments, expenses: expenses, flatId: flat.id, month: month);
        if (summary.income == 0 && summary.expenses == 0) continue;
        final net = summary.net;
        final alt = row % 2 == 0;
        final remark = net > 0 ? 'Profit' : net < 0 ? 'Loss' : 'Break-even';
        sheet.appendRow([flat.name, month, summary.income, summary.expenses, net, remark]);
        // Style row
        _styleDataRow(sheet, row, 6, alt: alt);
        // Income green
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row)).cellStyle = _dataStyle(alt: alt, bg: _successBg, textColor: _successText).copyWith(horizontalAlignVal: HorizontalAlign.Right);
        // Expense red
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row)).cellStyle = _dataStyle(alt: alt, bg: _dangerBg, textColor: _dangerText).copyWith(horizontalAlignVal: HorizontalAlign.Right);
        // Net with conditional
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row)).cellStyle = _netStyle(net, alt).copyWith(horizontalAlignVal: HorizontalAlign.Right);
        // Remark
        final remarkCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: row));
        if (net > 0) {
          remarkCell.cellStyle = _dataStyle(alt: alt, bg: _successBg, textColor: _successText).copyWith(horizontalAlignVal: HorizontalAlign.Center);
        } else if (net < 0) {
          remarkCell.cellStyle = _dataStyle(alt: alt, bg: _dangerBg, textColor: _dangerText).copyWith(horizontalAlignVal: HorizontalAlign.Center);
        } else {
          remarkCell.cellStyle = _dataStyle(alt: alt, bg: _neutralBg).copyWith(horizontalAlignVal: HorizontalAlign.Center);
        }
        // Currency right align
        for (var c in [2, 3, 4]) {
          final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: row));
          cell.cellStyle = cell.cellStyle!.copyWith(horizontalAlignVal: HorizontalAlign.Right);
        }
        row++;
      }
    }
    // Totals row
    double totalInc = 0, totalExp = 0;
    for (final p in payments) totalInc += p.amountPaid;
    for (final e in expenses) totalExp += e.amount;
    for (final r in leaseChequeRecords) totalExp += r.amount;
    final totalNet = totalInc - totalExp;
    sheet.appendRow(['TOTAL (All Flats)', '', totalInc, totalExp, totalNet, totalNet >= 0 ? 'Overall Profit' : 'Overall Loss']);
    final totalRow = row;
    _styleDataRow(sheet, totalRow, 6);
    for (var c = 0; c < 6; c++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: totalRow));
      cell.cellStyle = CellStyle(
        bold: true,
        fontSize: 11,
        fontColorHex: _white,
        backgroundColorHex: _accentHex,
        horizontalAlign: c >= 2 && c <= 4 ? HorizontalAlign.Right : HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
        leftBorder: Border(borderStyle: BorderStyle.Thin, borderColorHex: _accentHex),
        rightBorder: Border(borderStyle: BorderStyle.Thin, borderColorHex: _accentHex),
        topBorder: Border(borderStyle: BorderStyle.Thin, borderColorHex: _accentHex),
        bottomBorder: Border(borderStyle: BorderStyle.Thin, borderColorHex: _accentHex),
      );
    }
  }

  void _addChequePaymentHistorySheet(Excel excel) {
    final sheet = excel['Cheque Payment History'];
    sheet.appendRow(['Flat', 'Owner', 'Due Date', 'Paid Date', 'Amount (AED)', 'Month', 'Status']);
    _styleHeaderRow(sheet, 7);
    _autoWidths(sheet, [18.0, 20.0, 14.0, 14.0, 16.0, 12.0, 14.0]);

    final flatMap = {for (var f in flats) f.id: f};
    final sorted = List<LeaseChequeRecord>.from(leaseChequeRecords)..sort((a, b) => b.paidDate.compareTo(a.paidDate));
    for (var i = 0; i < sorted.length; i++) {
      final r = sorted[i];
      final flat = flatMap[r.flatId];
      final alt = i % 2 == 1;
      final status = r.paidDate.isAfter(r.dueDate) ? 'Late' : 'On Time';
      sheet.appendRow([flat?.name ?? 'Unknown', r.ownerName, _formatDate(r.dueDate), _formatDate(r.paidDate), r.amount, r.month, status]);
      _styleDataRow(sheet, i + 1, 7, alt: alt);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: i + 1)).cellStyle = _dataStyle(alt: alt).copyWith(horizontalAlignVal: HorizontalAlign.Right);
      final statusCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: i + 1));
      if (status == 'Late') {
        statusCell.cellStyle = _dataStyle(alt: alt, bg: _dangerBg, textColor: _dangerText).copyWith(horizontalAlignVal: HorizontalAlign.Center);
      } else {
        statusCell.cellStyle = _dataStyle(alt: alt, bg: _successBg, textColor: _successText).copyWith(horizontalAlignVal: HorizontalAlign.Center);
      }
    }
  }

  void _addTenantRentHistorySheet(Excel excel) {
    final sheet = excel['Tenant Rent History'];
    sheet.appendRow(['Tenant', 'Flat', 'Bed', 'Month', 'Amount Due (AED)', 'Amount Paid (AED)', 'Type', 'Status']);
    _styleHeaderRow(sheet, 8);
    _autoWidths(sheet, [20.0, 16.0, 12.0, 12.0, 16.0, 16.0, 12.0, 12.0]);

    final personMap = {for (var p in people) p.id: p};
    final flatMap = {for (var f in flats) f.id: f};
    final bedMap = {for (var b in beds) b.id: b};
    final sorted = List<Payment>.from(payments)..sort((a, b) => b.month.compareTo(a.month));
    for (var i = 0; i < sorted.length; i++) {
      final p = sorted[i];
      final person = personMap[p.personId];
      final flat = flatMap[p.flatId];
      final bed = bedMap[p.bedId];
      final status = p.amountPaid >= p.amountDue ? 'Paid' : p.amountPaid > 0 ? 'Partial' : 'Unpaid';
      final alt = i % 2 == 1;
      sheet.appendRow([person?.name ?? 'Unknown', flat?.name ?? 'Unknown', bed?.label ?? p.bedId, _formatMonth(p.month), p.amountDue, p.amountPaid, p.type.name, status]);
      _styleDataRow(sheet, i + 1, 8, alt: alt);
      // Status
      final statusCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: i + 1));
      if (status == 'Paid') {
        statusCell.cellStyle = _dataStyle(alt: alt, bg: _successBg, textColor: _successText).copyWith(horizontalAlignVal: HorizontalAlign.Center);
      } else if (status == 'Partial') {
        statusCell.cellStyle = _dataStyle(alt: alt, bg: _warnBg, textColor: _warnText).copyWith(horizontalAlignVal: HorizontalAlign.Center);
      } else {
        statusCell.cellStyle = _dataStyle(alt: alt, bg: _dangerBg, textColor: _dangerText).copyWith(horizontalAlignVal: HorizontalAlign.Center);
      }
      // Currency right
      for (var c in [4, 5]) {
        final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: i + 1));
        cell.cellStyle = _dataStyle(alt: alt).copyWith(horizontalAlignVal: HorizontalAlign.Right);
      }
      // Type center
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: i + 1)).cellStyle = _dataStyle(alt: alt).copyWith(horizontalAlignVal: HorizontalAlign.Center);
    }
  }

  void _addExpensesSheet(Excel excel) {
    final sheet = excel['Expenses'];
    sheet.appendRow(['Flat', 'Category', 'Amount (AED)', 'Date', 'Payment Method', 'Note', 'Status']);
    _styleHeaderRow(sheet, 7);
    _autoWidths(sheet, [18.0, 16.0, 16.0, 14.0, 16.0, 30.0, 14.0]);

    final flatMap = {for (var f in flats) f.id: f};
    final sorted = List<Expense>.from(expenses)..sort((a, b) => b.date.compareTo(a.date));
    for (var i = 0; i < sorted.length; i++) {
      final e = sorted[i];
      final flat = flatMap[e.flatId];
      final alt = i % 2 == 1;
      sheet.appendRow([flat?.name ?? 'Unknown', e.category.label, e.amount, _formatDate(e.date), e.paymentMethod ?? '', e.effectiveDescription ?? '', e.amount > 1000 ? 'High' : 'Normal']);
      _styleDataRow(sheet, i + 1, 7, alt: alt);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: i + 1)).cellStyle = _dataStyle(alt: alt, bg: _dangerBg, textColor: _dangerText).copyWith(horizontalAlignVal: HorizontalAlign.Right);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: i + 1)).cellStyle = _dataStyle(alt: alt).copyWith(horizontalAlignVal: HorizontalAlign.Left);
      final statusCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: i + 1));
      if (e.amount > 1000) {
        statusCell.cellStyle = _dataStyle(alt: alt, bg: _warnBg, textColor: _warnText).copyWith(horizontalAlignVal: HorizontalAlign.Center);
      } else {
        statusCell.cellStyle = _dataStyle(alt: alt, bg: _neutralBg).copyWith(horizontalAlignVal: HorizontalAlign.Center);
      }
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String _fmtAED(double v) => '${v.toStringAsFixed(2)} AED';

  String _formatMonth(String month) => month;
}
