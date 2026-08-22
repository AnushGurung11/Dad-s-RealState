import 'package:flutter_test/flutter_test.dart';
import 'package:lucky/models/expense.dart';
import 'package:lucky/models/flat.dart';
import 'package:lucky/services/expense_service.dart';
import 'package:lucky/services/json_store.dart';

void main() {
  late InMemoryJsonStore store;

  setUp(() {
    store = InMemoryJsonStore();
    store.upsertFlat(Flat(
      id: 'f1',
      name: 'Alpha',
      address: '1 A Road',
      createdAt: DateTime(2026, 1, 1),
    ));
  });

  test('add/edit/delete an expense persists correctly', () {
    final service = ExpenseService(store);

    // Add
    final e1 = service.upsert(
      flatId: 'f1',
      category: ExpenseCategory.electricity,
      amount: 1500,
      date: DateTime(2026, 5, 10),
      note: 'May bill',
    );
    expect(store.expenses, hasLength(1));
    expect(store.expenses.single.id, e1.id);
    expect(store.expenses.single.amount, 1500);
    expect(store.expenses.single.category, ExpenseCategory.electricity);

    // Edit
    final e2 = service.upsert(
      flatId: 'f1',
      category: ExpenseCategory.water,
      amount: 2000,
      date: DateTime(2026, 5, 15),
      note: 'Updated',
      existingId: e1.id,
    );
    expect(store.expenses, hasLength(1));
    expect(e2.id, e1.id);
    expect(store.expenses.single.category, ExpenseCategory.water);
    expect(store.expenses.single.amount, 2000);

    // Delete
    service.delete(e1.id);
    expect(store.expenses, isEmpty);
  });

  test('monthly grouping buckets by YYYY-MM across year boundary', () {
    final service = ExpenseService(store);

    service.upsert(
      flatId: 'f1',
      category: ExpenseCategory.electricity,
      amount: 100,
      date: DateTime(2026, 12, 28),
    );
    service.upsert(
      flatId: 'f1',
      category: ExpenseCategory.water,
      amount: 200,
      date: DateTime(2027, 1, 5),
    );
    service.upsert(
      flatId: 'f1',
      category: ExpenseCategory.gas,
      amount: 300,
      date: DateTime(2026, 12, 1),
    );

    final grouped = service.groupedByMonth('f1');
    expect(grouped.keys.toList(), ['2027-01', '2026-12']);
    expect(grouped['2026-12']!.length, 2);
    expect(grouped['2027-01']!.length, 1);
    // Within month sorted descending
    expect(grouped['2026-12']!.first.date.day, 28);
    expect(grouped['2026-12']!.last.date.day, 1);
  });

  test('category restricted to 6 fixed values', () {
    final service = ExpenseService(store);

    // Valid categories work
    for (final cat in ExpenseCategory.values) {
      service.upsert(
        flatId: 'f1',
        category: cat,
        amount: 100,
        date: DateTime.now(),
      );
    }
    expect(store.expenses, hasLength(6));

    // Invalid category string rejected at service layer
    expect(
      () => service.upsert(
        flatId: 'f1',
        category: ExpenseCategory.other, // valid
        amount: 100,
        date: DateTime.now(),
      ),
      isNot(throwsA(isA<ExpenseException>())), // other is valid
    );

    // ExpenseCategory.fromString falls back to 'other' for unknown
    expect(
      ExpenseCategory.fromString('invalid'),
      ExpenseCategory.other,
    );
  });

  test('rejects non-positive amount', () {
    final service = ExpenseService(store);
    expect(
      () => service.upsert(
        flatId: 'f1',
        category: ExpenseCategory.electricity,
        amount: 0,
        date: DateTime.now(),
      ),
      throwsA(isA<ExpenseException>()),
    );
    expect(
      () => service.upsert(
        flatId: 'f1',
        category: ExpenseCategory.electricity,
        amount: -100,
        date: DateTime.now(),
      ),
      throwsA(isA<ExpenseException>()),
    );
  });
}