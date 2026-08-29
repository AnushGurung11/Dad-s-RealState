import 'package:flutter_test/flutter_test.dart';
import 'package:lucky/models/expense.dart';
import 'package:lucky/models/lease_cheque_record.dart';
import 'package:lucky/models/lease_cheque_setting.dart';
import 'package:lucky/models/payment.dart';
import 'package:lucky/services/json_store.dart';
import 'package:lucky/services/transaction_edit_service.dart';

void main() {
  late InMemoryJsonStore store;
  late TransactionEditService service;

  setUp(() {
    store = InMemoryJsonStore();
    service = TransactionEditService(store);
  });

  test('editPayment updates only amount/date/description/paymentMethod; protected fields ignored', () async {
    final payment = Payment(
      id: 'p1',
      personId: 'person1',
      bedId: 'bed1',
      flatId: 'flat1',
      month: '2026-01',
      amountDue: 1000,
      amountPaid: 1000,
      type: PaymentType.rent,
      description: 'old',
      paymentMethod: 'cash',
    );
    store.upsertPayment(payment);

    await service.editPayment(
      'p1',
      amount: 2000,
      month: '2026-02',
      description: 'new desc',
      paymentMethod: 'bank',
      // Attempt to change protected fields - should be ignored
      personId: 'hacker',
      bedId: 'hackerBed',
      flatId: 'hackerFlat',
      type: 'deposit',
    );

    final updated = store.payments.singleWhere((p) => p.id == 'p1');
    expect(updated.amountPaid, 2000);
    expect(updated.month, '2026-02');
    expect(updated.description, 'new desc');
    expect(updated.paymentMethod, 'bank');
    // Protected fields unchanged
    expect(updated.personId, 'person1');
    expect(updated.bedId, 'bed1');
    expect(updated.flatId, 'flat1');
    expect(updated.type, PaymentType.rent);
  });

  test('every edit/delete call also produces exactly one audit_log entry with correct before/after snapshots', () async {
    final payment = Payment(
      id: 'p1',
      personId: 'person1',
      bedId: 'bed1',
      flatId: 'flat1',
      month: '2026-01',
      amountDue: 1000,
      amountPaid: 1000,
    );
    store.upsertPayment(payment);
    final beforeJson = payment.toJson();

    await service.editPayment('p1', amount: 1500);
    expect(store.auditLogs, hasLength(1));
    expect(store.auditLogs.first.beforeSnapshot, beforeJson);
    expect(store.auditLogs.first.afterSnapshot!['amountPaid'], 1500);

    await service.deletePayment('p1');
    expect(store.auditLogs, hasLength(2));
    expect(store.auditLogs.last.action.name, 'delete');
    expect(store.auditLogs.last.beforeSnapshot['id'], 'p1');
    expect(store.auditLogs.last.afterSnapshot, isNull);
  });

  test('deleteLeaseChequeRecord does NOT alter LeaseChequeSetting.nextDueDate', () async {
    final setting = LeaseChequeSetting(
      id: 's1',
      flatId: 'f1',
      ownerName: 'Owner',
      amount: 4000,
      nextDueDate: DateTime(2026, 12, 1),
      intervalMonths: 2,
    );
    store.upsertChequeSetting(setting);
    final record = LeaseChequeRecord(
      id: 'r1',
      flatId: 'f1',
      ownerName: 'Owner',
      amount: 4000,
      dueDate: DateTime(2026, 10, 1),
      paidDate: DateTime(2026, 10, 5),
      month: '2026-10',
    );
    store.upsertChequeRecord(record);
    final originalDue = setting.nextDueDate;

    await service.deleteLeaseChequeRecord('r1');
    expect(store.leaseChequeRecords, isEmpty);
    expect(store.leaseChequeSettings.single.nextDueDate, originalDue);
    // Audit log created
    expect(store.auditLogs, hasLength(1));
  });

  test('editExpense and deleteExpense also audit', () async {
    final expense = Expense(
      id: 'e1',
      flatId: 'f1',
      category: ExpenseCategory.electricity,
      amount: 100,
      date: DateTime(2026, 1, 10),
      description: 'old',
    );
    store.upsertExpense(expense);
    await service.editExpense('e1', amount: 200, description: 'new');
    expect(store.expenses.single.amount, 200);
    expect(store.auditLogs, hasLength(1));

    await service.deleteExpense('e1');
    expect(store.expenses, isEmpty);
    expect(store.auditLogs, hasLength(2));
  });

  test('editLeaseChequeRecord does not alter setting nextDueDate either', () async {
    final setting = LeaseChequeSetting(
      id: 's1',
      flatId: 'f1',
      ownerName: 'Owner',
      amount: 4000,
      nextDueDate: DateTime(2026, 12, 1),
    );
    store.upsertChequeSetting(setting);
    final record = LeaseChequeRecord(
      id: 'r1',
      flatId: 'f1',
      ownerName: 'Owner',
      amount: 4000,
      dueDate: DateTime(2026, 10, 1),
      paidDate: DateTime(2026, 10, 5),
      month: '2026-10',
    );
    store.upsertChequeRecord(record);
    final originalDue = setting.nextDueDate;
    await service.editLeaseChequeRecord('r1', amount: 5000);
    expect(store.leaseChequeRecords.single.amount, 5000);
    expect(store.leaseChequeSettings.single.nextDueDate, originalDue);
  });
}
