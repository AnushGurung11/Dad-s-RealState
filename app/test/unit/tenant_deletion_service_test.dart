import 'package:flutter_test/flutter_test.dart';
import 'package:lucky/models/payment.dart';
import 'package:lucky/models/person.dart';
import 'package:lucky/services/tenant_deletion_service.dart';

void main() {
  const person = Person(id: 'p1', name: 'Alice', contact: '9000000001');

  Payment paymentFor(String personId, {PaymentType type = PaymentType.rent}) =>
      Payment(
        id: 'pay-$personId-$type',
        personId: personId,
        bedId: 'b1',
        flatId: 'f1',
        month: '2026-07',
        amountDue: 4000,
        amountPaid: 4000,
        type: type,
      );

  test('canHardDelete is true with ZERO payment records', () {
    expect(TenantDeletionService.canHardDelete(person, []), isTrue);
  });

  test('canHardDelete is false when even ONE rent record exists', () {
    expect(
      TenantDeletionService.canHardDelete(person, [paymentFor('p1')]),
      isFalse,
    );
  });

  test('a deposit alone counts as financial history too', () {
    expect(
      TenantDeletionService.canHardDelete(person, [
        paymentFor('p1', type: PaymentType.deposit),
      ]),
      isFalse,
    );
  });

  test("other people's payments do not block deletion", () {
    expect(
      TenantDeletionService.canHardDelete(person, [paymentFor('p2')]),
      isTrue,
    );
  });
}
