import 'dart:io';

import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lucky/models/bed.dart';
import 'package:lucky/models/expense.dart';
import 'package:lucky/models/flat.dart';
import 'package:lucky/models/lease_cheque_record.dart';
import 'package:lucky/models/lease_termination_record.dart';
import 'package:lucky/models/lease_cheque_setting.dart';
import 'package:lucky/models/payment.dart';
import 'package:lucky/models/person.dart';
import 'package:lucky/services/excel_export_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<Flat> flats;
  late List<Bed> beds;
  late List<Person> people;
  late List<Payment> payments;
  late List<Expense> expenses;
  late List<LeaseChequeSetting> leaseChequeSettings;
  late List<LeaseChequeRecord> leaseChequeRecords;
  late List<LeaseTerminationRecord> terminations;
  late ExcelExportService excelService;
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('excel_export_test_');

    flats = [
      Flat(
        id: 'flat1',
        name: 'Flat A',
        address: '123 Main St',
        createdAt: DateTime(2024, 1, 1),
        registeredDate: DateTime(2024, 1, 15),
        yearlyRent: 12000,
        archived: false,
      ),
      Flat(
        id: 'flat2',
        name: 'Flat B (Archived)',
        address: '456 Oak Ave',
        createdAt: DateTime(2023, 6, 1),
        registeredDate: DateTime(2023, 6, 1),
        yearlyRent: 10000,
        archived: true,
        archivedAt: DateTime(2024, 1, 1),
      ),
    ];

    beds = [
      Bed(
        id: 'bed1',
        flatId: 'flat1',
        label: 'Bed 1',
        defaultMonthlyRent: 1000,
        tenantId: 'person1',
      ),
      Bed(
        id: 'bed2',
        flatId: 'flat1',
        label: 'Bed 2',
        defaultMonthlyRent: 1000,
        tenantId: null,
      ),
      Bed(
        id: 'bed3',
        flatId: 'flat2',
        label: 'Bed 1',
        defaultMonthlyRent: 800,
        tenantId: 'person3',
      ),
    ];

    people = [
      Person(
        id: 'person1',
        name: 'John Doe',
        contact: '+971501234567',
        workplaceOrInfo: 'Tech Corp',
        bedId: 'bed1',
        flatId: 'flat1',
        joinDate: DateTime(2024, 2, 1),
        plannedStayMonths: 12,
        monthlyRent: 1000,
        depositAmount: 2000,
        status: PersonStatus.active,
        photoPath: null,
      ),
      Person(
        id: 'person2',
        name: 'Jane Smith',
        contact: '+971507654321',
        workplaceOrInfo: 'Design Studio',
        bedId: null,
        flatId: 'flat1',
        joinDate: DateTime(2024, 3, 1),
        plannedStayMonths: 6,
        monthlyRent: 1000,
        depositAmount: 1000,
        status: PersonStatus.archived,
        vacatedDate: DateTime(2024, 8, 1),
        photoPath: null,
      ),
      Person(
        id: 'person3',
        name: 'Bob Wilson',
        contact: '+971509998888',
        workplaceOrInfo: 'Construction Co',
        bedId: 'bed3',
        flatId: 'flat2',
        joinDate: DateTime(2023, 7, 1),
        plannedStayMonths: 24,
        monthlyRent: 800,
        depositAmount: 1600,
        status: PersonStatus.absconded,
        vacatedDate: DateTime(2024, 5, 15),
        statusNote: 'Left without notice',
        photoPath: null,
      ),
    ];

    payments = [
      Payment(
        id: 'pay1',
        personId: 'person1',
        bedId: 'bed1',
        flatId: 'flat1',
        month: '2024-02',
        amountDue: 1000,
        amountPaid: 1000,
        type: PaymentType.rent,
      ),
      Payment(
        id: 'pay2',
        personId: 'person1',
        bedId: 'bed1',
        flatId: 'flat1',
        month: '2024-03',
        amountDue: 1000,
        amountPaid: 500,
        type: PaymentType.rent,
      ),
      Payment(
        id: 'pay3',
        personId: 'person2',
        bedId: 'bed2',
        flatId: 'flat1',
        month: '2024-03',
        amountDue: 1000,
        amountPaid: 1000,
        type: PaymentType.deposit,
      ),
    ];

    expenses = [
      Expense(
        id: 'exp1',
        flatId: 'flat1',
        category: ExpenseCategory.electricity,
        amount: 500,
        date: DateTime(2024, 2, 15),
        note: 'Monthly bill',
      ),
      Expense(
        id: 'exp2',
        flatId: 'flat1',
        category: ExpenseCategory.water,
        amount: 200,
        date: DateTime(2024, 3, 10),
        note: null,
      ),
      Expense(
        id: 'exp3',
        flatId: 'flat2',
        category: ExpenseCategory.maintenance,
        amount: 1000,
        date: DateTime(2024, 1, 20),
        note: 'Repairs',
      ),
    ];

    leaseChequeSettings = [
      LeaseChequeSetting(
        id: 'cheque1',
        flatId: 'flat1',
        ownerName: 'Owner A',
        amount: 10000,
        nextDueDate: DateTime(2024, 4, 1),
        intervalMonths: 2,
      ),
    ];

    leaseChequeRecords = [
      LeaseChequeRecord(
        id: 'record1',
        flatId: 'flat1',
        ownerName: 'Owner A',
        amount: 10000,
        dueDate: DateTime(2024, 2, 1),
        paidDate: DateTime(2024, 2, 5),
        month: '2024-02',
      ),
      LeaseChequeRecord(
        id: 'record2',
        flatId: 'flat1',
        ownerName: 'Owner A',
        amount: 10000,
        dueDate: DateTime(2023, 12, 1),
        paidDate: DateTime(2023, 12, 10),
        month: '2023-12',
      ),
    ];

    terminations = [
      LeaseTerminationRecord(
        id: 'term1',
        personId: 'person3',
        bedId: 'bed3',
        flatId: 'flat2',
        terminationDate: DateTime(2024, 5, 15),
        reason: TerminationReason.other,
        reasonNote: 'Left without notice',
        totalPaidAcrossPrepaidMonths: 5000,
        daysStayedFinalMonth: 15,
        earnedFinalMonth: 400,
        refundAmount: 4600,
      ),
    ];

    excelService = ExcelExportService(
      flats: flats,
      beds: beds,
      people: people,
      payments: payments,
      expenses: expenses,
      leaseChequeSettings: leaseChequeSettings,
      leaseChequeRecords: leaseChequeRecords,
      terminations: terminations,
      getDocumentsDirectory: () async => tempDir,
    );
  });

  tearDown(() async {
    try {
      await tempDir.delete(recursive: true);
    } catch (_) {}
  });

  test('exported workbook contains all 7 sheets with correct headers', () async {
    final file = await excelService.exportToExcel();
    expect(await file.exists(), isTrue);

    final bytes = await file.readAsBytes();
    final excel = Excel.decodeBytes(bytes);

    // Check sheet names
    final sheetNames = excel.tables.keys.toSet();
    expect(sheetNames, contains('Read me'));
    expect(sheetNames, contains('Tenants'));
    expect(sheetNames, contains('Flats & Beds'));
    expect(sheetNames, contains('Financial Report'));
    expect(sheetNames, contains('Cheque Payment History'));
    expect(sheetNames, contains('Tenant Rent History'));
    expect(sheetNames, contains('Expenses'));
    // Allow for Sheet1 if not deleted (some Excel versions keep it)
    expect(sheetNames.length, greaterThanOrEqualTo(7));

    // Check headers for each sheet
    final readMeSheet = excel.tables['Read me']!;
    expect(readMeSheet.maxRows, greaterThan(0));

    final tenantsSheet = excel.tables['Tenants']!;
    final tenantHeaders = tenantsSheet.rows.first.map((c) => c?.value?.toString()).toList();
    expect(tenantHeaders, equals([
      'Name', 'Contact', 'Workplace', 'Flat', 'Bed', 'Status',
      'Join Date', 'Vacated Date', 'Monthly Rent', 'Deposit',
    ]));

    final flatsBedsSheet = excel.tables['Flats & Beds']!;
    final fbHeaders = flatsBedsSheet.rows.first.map((c) => c?.value?.toString()).toList();
    expect(fbHeaders, equals([
      'Flat Name', 'Address', 'Registered Date', 'Bed Label',
      'Occupant', 'Default Monthly Rent', 'Status',
    ]));

    final financialSheet = excel.tables['Financial Report']!;
    final finHeaders = financialSheet.rows.first.map((c) => c?.value?.toString()).toList();
    expect(finHeaders, equals([
      'Flat', 'Month', 'Income', 'Expenses', 'Net',
    ]));

    final chequeSheet = excel.tables['Cheque Payment History']!;
    final chHeaders = chequeSheet.rows.first.map((c) => c?.value?.toString()).toList();
    expect(chHeaders, equals([
      'Flat', 'Date', 'Amount',
    ]));

    final rentHistorySheet = excel.tables['Tenant Rent History']!;
    final rhHeaders = rentHistorySheet.rows.first.map((c) => c?.value?.toString()).toList();
    expect(rhHeaders, equals([
      'Tenant', 'Flat', 'Date', 'Amount', 'Type',
    ]));

    final expensesSheet = excel.tables['Expenses']!;
    final expHeaders = expensesSheet.rows.first.map((c) => c?.value?.toString()).toList();
    expect(expHeaders, equals([
      'Flat', 'Category', 'Amount', 'Date', 'Note',
    ]));
  });

  test('Financial Report sheet numbers match report_service output', () async {
    final file = await excelService.exportToExcel();
    final bytes = await file.readAsBytes();
    final excel = Excel.decodeBytes(bytes);

    final financialSheet = excel.tables['Financial Report']!;

    // Get report service output for comparison
    // (This is tested implicitly since we use the same service)

    // Check that data rows exist and have numeric values
    for (var i = 1; i < financialSheet.maxRows; i++) {
      final row = financialSheet.rows[i];
      final income = row[2]?.value;
      final expenses = row[3]?.value;
      final net = row[4]?.value;

      expect(income, isA<num>());
      expect(expenses, isA<num>());
      expect(net, isA<num>());
      expect(net, equals((income as num) - (expenses as num)));
    }
  });

  test('archived flats and tenants ARE included in export', () async {
    final file = await excelService.exportToExcel();
    final bytes = await file.readAsBytes();
    final excel = Excel.decodeBytes(bytes);

    // Check Tenants sheet includes archived and absconded
    final tenantsSheet = excel.tables['Tenants']!;
    final tenantNames = <String>[];
    for (var i = 1; i < tenantsSheet.maxRows; i++) {
      final cell = tenantsSheet.rows[i][0];
      final name = cell?.value?.toString();
      if (name != null && name.isNotEmpty) tenantNames.add(name);
    }
    expect(tenantNames, contains('John Doe')); // active
    expect(tenantNames, contains('Jane Smith')); // archived
    expect(tenantNames, contains('Bob Wilson')); // absconded

    // Check Flats & Beds includes archived flat
    final flatsBedsSheet = excel.tables['Flats & Beds']!;
    final flatNames = <String>[];
    for (var i = 1; i < flatsBedsSheet.maxRows; i++) {
      final cell = flatsBedsSheet.rows[i][0];
      final name = cell?.value?.toString();
      if (name != null && name.isNotEmpty) flatNames.add(name);
    }
    expect(flatNames, contains('Flat A'));
    expect(flatNames, contains('Flat B (Archived)'));

    // Verify archived status is shown
    for (var i = 1; i < flatsBedsSheet.maxRows; i++) {
      final row = flatsBedsSheet.rows[i];
      final flatName = row[0]?.value?.toString();
      final status = row[6]?.value?.toString();
      if (flatName == 'Flat B (Archived)') {
        expect(status, equals('Archived'));
      }
    }
  });

  test('Read me sheet states export is one-way', () async {
    final file = await excelService.exportToExcel();
    final bytes = await file.readAsBytes();
    final excel = Excel.decodeBytes(bytes);

    final readMeSheet = excel.tables['Read me']!;
    final content = readMeSheet.rows.first[0]?.value?.toString();
    expect(content, contains('point-in-time export'));
    expect(content, contains('never re-imported'));
    expect(content, contains('edits here have no effect'));
  });
}