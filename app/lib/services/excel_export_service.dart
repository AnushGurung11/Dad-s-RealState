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
import '../models/payment.dart'
    hide PaymentStatus, PaymentType;
import '../models/person.dart';
import '../services/report_service.dart';

/// Service for exporting all data to an Excel workbook (one-way, for viewing only).
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

  /// Optional override for getting the documents directory (used in tests).
  final Future<Directory> Function()? getDocumentsDirectory;

  /// Exports all data to an .xlsx file with 7 sheets.
  /// Returns the file; the caller should show a share sheet.
  Future<File> exportToExcel() async {
    final excel = Excel.createExcel();

    // Remove default sheet
    excel.delete('Sheet1');

    // Sheet 1: Read me
    _addReadMeSheet(excel);

    // Sheet 2: Tenants
    _addTenantsSheet(excel);

    // Sheet 3: Flats & Beds
    _addFlatsAndBedsSheet(excel);

    // Sheet 4: Financial Report
    _addFinancialReportSheet(excel);

    // Sheet 5: Cheque Payment History
    _addChequePaymentHistorySheet(excel);

    // Sheet 6: Tenant Rent History
    _addTenantRentHistorySheet(excel);

    // Sheet 7: Expenses
    _addExpensesSheet(excel);

    // Save file
    final docsDir = getDocumentsDirectory != null
        ? await getDocumentsDirectory!()
        : await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').replaceAll('.', '-');
    final file = File('${docsDir.path}/lucky-export-$timestamp.xlsx');

    final bytes = excel.encode();
    if (bytes == null) {
      throw StateError('Failed to encode Excel file');
    }
    await file.writeAsBytes(bytes, flush: true);

    return file;
  }

  void _addReadMeSheet(Excel excel) {
    final sheet = excel['Read me'];
    sheet.appendRow([
      'This file is a point-in-time export for viewing/record-keeping only '
      'and is never re-imported into the app — edits here have no effect.',
    ]);
  }

  void _addTenantsSheet(Excel excel) {
    final sheet = excel['Tenants'];

    // Headers
    sheet.appendRow([
      'Name',
      'Contact',
      'Workplace',
      'Flat',
      'Bed',
      'Status',
      'Join Date',
      'Vacated Date',
      'Monthly Rent',
      'Deposit',
    ]);

    // Build lookup maps
    final flatMap = {for (var f in flats) f.id: f};
    final bedMap = {for (var b in beds) b.id: b};

    for (final person in people) {
      final flat = person.flatId != null ? flatMap[person.flatId!] : null;
      final bed = person.bedId != null ? bedMap[person.bedId!] : null;

      sheet.appendRow([
        person.name,
        person.contact,
        person.workplaceOrInfo ?? '',
        flat?.name ?? '',
        bed?.label ?? '',
        person.status.name,
        person.joinDate != null
            ? _formatDate(person.joinDate!)
            : '',
        person.vacatedDate != null
            ? _formatDate(person.vacatedDate!)
            : '',
        person.monthlyRent ?? 0,
        person.depositAmount ?? 0,
      ]);
    }
  }

  void _addFlatsAndBedsSheet(Excel excel) {
    final sheet = excel['Flats & Beds'];

    sheet.appendRow([
      'Flat Name',
      'Address',
      'Registered Date',
      'Bed Label',
      'Occupant',
      'Default Monthly Rent',
      'Status',
    ]);

    final personMap = {for (var p in people) p.id: p};

    for (final flat in flats) {
      final flatBeds = beds.where((b) => b.flatId == flat.id).toList();
      if (flatBeds.isEmpty) {
        sheet.appendRow([
          flat.name,
          flat.address,
          flat.registeredDate != null
              ? _formatDate(flat.registeredDate!)
              : '',
          '',
          '',
          '',
          flat.archived ? 'Archived' : 'Active',
        ]);
      } else {
        for (final bed in flatBeds) {
          final occupant = bed.tenantId != null ? personMap[bed.tenantId!] : null;
          sheet.appendRow([
            flat.name,
            flat.address,
            flat.registeredDate != null
                ? _formatDate(flat.registeredDate!)
                : '',
            bed.label,
            occupant?.name ?? 'Vacant',
            bed.defaultMonthlyRent,
            flat.archived ? 'Archived' : 'Active',
          ]);
        }
      }
    }
  }

  void _addFinancialReportSheet(Excel excel) {
    final sheet = excel['Financial Report'];

    sheet.appendRow([
      'Flat',
      'Month',
      'Income',
      'Expenses',
      'Net',
    ]);

    // Get all months present in payments or expenses
    final months = <String>{};
    for (final p in payments) {
      months.add(p.month);
    }
    for (final e in expenses) {
      months.add(monthKey(e.date));
    }

    final sortedMonths = months.toList()..sort();

    for (final flat in flats) {
      for (final month in sortedMonths) {
        final summary = ReportService.flatSummary(
          payments: payments,
          expenses: expenses,
          flatId: flat.id,
          month: month,
        );
        // Only include months with data
        if (summary.income > 0 || summary.expenses > 0) {
          sheet.appendRow([
            flat.name,
            month,
            summary.income,
            summary.expenses,
            summary.net,
          ]);
        }
      }
    }
  }

  void _addChequePaymentHistorySheet(Excel excel) {
    final sheet = excel['Cheque Payment History'];

    sheet.appendRow([
      'Flat',
      'Date',
      'Amount',
    ]);

    final flatMap = {for (var f in flats) f.id: f};

    // Sort by paidDate descending
    final sortedRecords = List<LeaseChequeRecord>.from(leaseChequeRecords)
      ..sort((a, b) => b.paidDate.compareTo(a.paidDate));

    for (final record in sortedRecords) {
      final flat = flatMap[record.flatId];
      sheet.appendRow([
        flat?.name ?? 'Unknown',
        _formatDate(record.paidDate),
        record.amount,
      ]);
    }
  }

  void _addTenantRentHistorySheet(Excel excel) {
    final sheet = excel['Tenant Rent History'];

    sheet.appendRow([
      'Tenant',
      'Flat',
      'Date',
      'Amount',
      'Type',
    ]);

    final personMap = {for (var p in people) p.id: p};
    final flatMap = {for (var f in flats) f.id: f};

    // Sort by month descending (most recent first)
    final sortedPayments = List<Payment>.from(payments)
      ..sort((a, b) => b.month.compareTo(a.month));

    for (final payment in sortedPayments) {
      final person = personMap[payment.personId];
      final flat = flatMap[payment.flatId];
      sheet.appendRow([
        person?.name ?? 'Unknown',
        flat?.name ?? 'Unknown',
        _formatMonth(payment.month),
        payment.amountPaid,
        payment.type.name,
      ]);
    }
  }

  void _addExpensesSheet(Excel excel) {
    final sheet = excel['Expenses'];

    sheet.appendRow([
      'Flat',
      'Category',
      'Amount',
      'Date',
      'Note',
    ]);

    final flatMap = {for (var f in flats) f.id: f};

    // Sort by date descending
    final sortedExpenses = List<Expense>.from(expenses)
      ..sort((a, b) => b.date.compareTo(a.date));

    for (final expense in sortedExpenses) {
      final flat = flatMap[expense.flatId];
      sheet.appendRow([
        flat?.name ?? 'Unknown',
        expense.category.label,
        expense.amount,
        _formatDate(expense.date),
        expense.note ?? '',
      ]);
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  String _formatMonth(String month) {
    // month is already YYYY-MM format
    return month;
  }
}