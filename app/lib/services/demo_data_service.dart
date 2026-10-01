import '../config.dart';
import '../models/bed.dart';
import '../models/expense.dart';
import '../models/flat.dart';
import '../models/lease_cheque_record.dart';
import '../models/lease_cheque_setting.dart';
import '../models/payment.dart';
import '../models/person.dart';
import 'json_store.dart';

/// Fills a store with three fully populated months of realistic sample data.
///
/// This exists so the month navigation can be exercised against something: a
/// brand-new install has no history, so stepping back a month would show an
/// empty screen and prove nothing. Every record is written through the normal
/// store API so the data is indistinguishable from hand-entered data, and it
/// spans the two months before the current one through to the current month.
class DemoDataService {
  const DemoDataService(this.store);

  final JsonStore store;

  /// Months of history to generate, ending with the current month.
  static const int monthsOfHistory = 3;

  bool get hasExistingData =>
      store.flats.isNotEmpty || store.people.isNotEmpty || store.payments.isNotEmpty;

  /// Seeds flats, beds, tenants, rent payments, expenses and lease cheques.
  ///
  /// No-ops when the store already holds a flat or tenant so a user cannot
  /// accidentally mix sample data into their real records.
  void seed() {
    if (hasExistingData) return;

    store.runBatched(() {
      for (final flat in _flats) {
        store.upsertFlat(flat);
      }
      for (final bed in _beds) {
        store.upsertBed(bed);
      }
      for (final person in _people) {
        store.upsertPerson(person);
      }
      for (final setting in _chequeSettings) {
        store.upsertChequeSetting(setting);
      }
      for (final payment in _payments) {
        store.upsertPayment(payment);
      }
      for (final expense in _expenses) {
        store.upsertExpense(expense);
      }
      for (final record in _chequeRecords) {
        store.upsertChequeRecord(record);
      }
    });
  }

  /// The three months the sample data covers, oldest first.
  static List<String> coveredMonths() {
    final now = DateTime.now();
    return List.generate(monthsOfHistory, (i) {
      final offset = monthsOfHistory - 1 - i;
      return monthKey(DateTime(now.year, now.month - offset, 1));
    });
  }

  static final List<Flat> _flats = [
    Flat(
      id: 'demo_flat_a',
      name: 'Kopila Residency A',
      address: 'Lalitpur, Jhamsikhel Road',
      createdAt: DateTime(2024, 1, 5),
      registeredDate: DateTime(2024, 1, 10),
      contractPerson: 'Ramesh Maharjan',
      yearlyRent: 360000,
      archived: false,
      archivedAt: null,
      leasePaidThroughDate: null,
      frequencyMonths: 12,
      landlineNumber: '01-4455667',
      landlineRegisteredName: 'Ramesh Maharjan',
      esewaNumber: '9801234567',
      wifiName: 'Kopila-5G',
      wifiPassword: 'kopila@2024',
    ),
    Flat(
      id: 'demo_flat_b',
      name: 'Kopila Residency B',
      address: 'Lalitpur, Jhamsikhel Road',
      createdAt: DateTime(2024, 6, 1),
      registeredDate: DateTime(2024, 6, 15),
      contractPerson: 'Sita Maharjan',
      yearlyRent: 300000,
      archived: false,
      archivedAt: null,
      leasePaidThroughDate: null,
      frequencyMonths: 6,
      landlineNumber: null,
      landlineRegisteredName: null,
      esewaNumber: '9812345678',
      wifiName: 'Kopila-2G',
      wifiPassword: 'kopila@resb',
    ),
    Flat(
      id: 'demo_flat_c',
      name: 'Kopila Residency C',
      address: 'Lalitpur, Pulchowk',
      createdAt: DateTime(2023, 11, 2),
      registeredDate: DateTime(2023, 11, 20),
      contractPerson: 'Bishal Shrestha',
      yearlyRent: 240000,
      archived: false,
      archivedAt: null,
      leasePaidThroughDate: null,
      frequencyMonths: 12,
      landlineNumber: null,
      landlineRegisteredName: null,
      esewaNumber: null,
      wifiName: 'Kopila-Guest',
      wifiPassword: 'guest@2023',
    ),
  ];

  /// Six beds in A, four in B, three in C.
  static final List<Bed> _beds = [
    for (var i = 1; i <= 6; i++)
      Bed(
        id: 'demo_bed_a$i',
        flatId: 'demo_flat_a',
        label: 'Bed $i',
        defaultMonthlyRent: 9000,
        tenantId: i <= 4 ? 'demo_person_a$i' : null,
      ),
    for (var i = 1; i <= 4; i++)
      Bed(
        id: 'demo_bed_b$i',
        flatId: 'demo_flat_b',
        label: 'Bed $i',
        defaultMonthlyRent: 8000,
        tenantId: i <= 3 ? 'demo_person_b$i' : null,
      ),
    for (var i = 1; i <= 3; i++)
      Bed(
        id: 'demo_bed_c$i',
        flatId: 'demo_flat_c',
        label: 'Bed $i',
        defaultMonthlyRent: 7000,
        tenantId: i <= 2 ? 'demo_person_c$i' : null,
      ),
  ];

  static final List<Person> _people = [
    Person(
      id: 'demo_person_a1',
      name: 'Anil Maharjan',
      contact: '9801111111',
      workplaceOrInfo: 'Software engineer, F1Soft',
      country: 'Nepal',
      bedId: 'demo_bed_a1',
      flatId: 'demo_flat_a',
      joinDate: DateTime(2025, 4, 1),
      plannedStayMonths: 18,
      vacatedDate: null,
      depositAmount: 18000,
      monthlyRent: 9000,
      others: 'Vegetarian',
      status: PersonStatus.active,
    ),
    Person(
      id: 'demo_person_a2',
      name: 'Sabina Tamang',
      contact: '9802222222',
      workplaceOrInfo: 'Accountant',
      country: 'Nepal',
      bedId: 'demo_bed_a2',
      flatId: 'demo_flat_a',
      joinDate: DateTime(2025, 7, 15),
      plannedStayMonths: null,
      vacatedDate: null,
      depositAmount: 18000,
      monthlyRent: 9000,
      others: null,
      status: PersonStatus.active,
    ),
    Person(
      id: 'demo_person_a3',
      name: 'Nirajan Shakya',
      contact: '9803333333',
      workplaceOrInfo: 'Student, TU',
      country: 'Nepal',
      bedId: 'demo_bed_a3',
      flatId: 'demo_flat_a',
      joinDate: DateTime(2026, 1, 10),
      plannedStayMonths: 12,
      vacatedDate: null,
      depositAmount: 15000,
      monthlyRent: 9000,
      others: null,
      status: PersonStatus.active,
    ),
    Person(
      id: 'demo_person_a4',
      name: 'Prakash Adhikari',
      contact: '9804444444',
      workplaceOrInfo: 'Teacher',
      country: 'Nepal',
      bedId: 'demo_bed_a4',
      flatId: 'demo_flat_a',
      joinDate: DateTime(2024, 9, 1),
      plannedStayMonths: null,
      vacatedDate: DateTime(2026, 2, 28),
      depositAmount: 18000,
      monthlyRent: 9000,
      others: null,
      status: PersonStatus.archived,
      statusDate: DateTime(2026, 2, 28),
      statusNote: 'Left to join family abroad',
    ),
    Person(
      id: 'demo_person_b1',
      name: 'Deepika Rai',
      contact: '9811111111',
      workplaceOrInfo: 'Nurse, Patan Hospital',
      country: 'Nepal',
      bedId: 'demo_bed_b1',
      flatId: 'demo_flat_b',
      joinDate: DateTime(2025, 2, 1),
      plannedStayMonths: 24,
      vacatedDate: null,
      depositAmount: 16000,
      monthlyRent: 8000,
      others: null,
      status: PersonStatus.active,
    ),
    Person(
      id: 'demo_person_b2',
      name: 'Sanjay Karki',
      contact: '9812222222',
      workplaceOrInfo: 'Shop owner',
      country: 'Nepal',
      bedId: 'demo_bed_b2',
      flatId: 'demo_flat_b',
      joinDate: DateTime(2025, 8, 20),
      plannedStayMonths: null,
      vacatedDate: null,
      depositAmount: 16000,
      monthlyRent: 8000,
      others: null,
      status: PersonStatus.active,
    ),
    Person(
      id: 'demo_person_b3',
      name: 'Manisha Gurung',
      contact: '9813333333',
      workplaceOrInfo: 'Designer',
      country: 'Nepal',
      bedId: 'demo_bed_b3',
      flatId: 'demo_flat_b',
      joinDate: DateTime(2026, 2, 1),
      plannedStayMonths: 6,
      vacatedDate: null,
      depositAmount: 12000,
      monthlyRent: 8000,
      others: null,
      status: PersonStatus.active,
    ),
    Person(
      id: 'demo_person_c1',
      name: 'Rajesh Lama',
      contact: '9821111111',
      workplaceOrInfo: 'Carpenter',
      country: 'Nepal',
      bedId: 'demo_bed_c1',
      flatId: 'demo_flat_c',
      joinDate: DateTime(2024, 3, 5),
      plannedStayMonths: null,
      vacatedDate: null,
      depositAmount: 14000,
      monthlyRent: 7000,
      others: null,
      status: PersonStatus.active,
    ),
    Person(
      id: 'demo_person_c2',
      name: 'Aisha Chhetri',
      contact: '9822222222',
      workplaceOrInfo: 'Bank officer',
      country: 'Nepal',
      bedId: 'demo_bed_c2',
      flatId: 'demo_flat_c',
      joinDate: DateTime(2025, 11, 1),
      plannedStayMonths: 12,
      vacatedDate: null,
      depositAmount: 14000,
      monthlyRent: 7000,
      others: null,
      status: PersonStatus.active,
    ),
  ];

  static List<LeaseChequeSetting> get _chequeSettings => [
        LeaseChequeSetting(
          id: 'demo_setting_a',
          flatId: 'demo_flat_a',
          ownerName: 'Ramesh Maharjan',
          amount: 360000,
          nextDueDate: _monthDay(9, 10),
          intervalMonths: 12,
          notifyEnabled: true,
        ),
        LeaseChequeSetting(
          id: 'demo_setting_b',
          flatId: 'demo_flat_b',
          ownerName: 'Sita Maharjan',
          amount: 300000,
          nextDueDate: _monthDay(5, 15),
          intervalMonths: 6,
          notifyEnabled: true,
        ),
        LeaseChequeSetting(
          id: 'demo_setting_c',
          flatId: 'demo_flat_c',
          ownerName: 'Bishal Shrestha',
          amount: 240000,
          nextDueDate: _monthDay(12, 5),
          intervalMonths: 12,
          notifyEnabled: false,
        ),
      ];

  /// Rent for every occupied bed in every covered month, plus a deposit.
  static List<Payment> get _payments {
    final payments = <Payment>[];

    // A one-off deposit when the newest tenant joined.
    payments.add(Payment(
      id: 'demo_pay_deposit_a3',
      personId: 'demo_person_a3',
      bedId: 'demo_bed_a3',
      flatId: 'demo_flat_a',
      month: monthKey(_people.firstWhere((p) => p.id == 'demo_person_a3').joinDate!),
      amountDue: 15000,
      amountPaid: 15000,
      type: PaymentType.deposit,
      description: 'Security deposit',
      paymentMethod: 'Bank transfer',
    ));

    for (final month in coveredMonths()) {
      for (final person in _people.where((p) => p.status == PersonStatus.active)) {
        // Only charge tenants whose stay covers this month.
        final joined = person.joinDate!;
        final reference = DateTime.parse('$month-01');
        if (reference.isBefore(DateTime(joined.year, joined.month, 1))) continue;
        if (person.vacatedDate != null &&
            reference.isAfter(DateTime(person.vacatedDate!.year, person.vacatedDate!.month, 1))) {
          continue;
        }

        final due = person.monthlyRent ?? 0;
        // The newest month is deliberately partial for one tenant so the
        // "Unpaid"/partial states are exercised.
        final partial = month == coveredMonths().last && person.id == 'demo_person_b3';
        payments.add(Payment(
          id: 'demo_pay_${person.id}_$month',
          personId: person.id,
          bedId: person.bedId!,
          flatId: person.flatId!,
          month: month,
          amountDue: due,
          amountPaid: partial ? due / 2 : due,
          type: PaymentType.rent,
          description: 'Monthly rent',
          paymentMethod: partial ? 'Cash' : 'Bank transfer',
        ));
      }
    }

    return payments;
  }

  /// Utility bills and upkeep spread across flats and months.
  static List<Expense> get _expenses {
    final expenses = <Expense>[];
    const perFlat = <String, double>{
      'demo_flat_a': 1,
      'demo_flat_b': 0.8,
      'demo_flat_c': 0.6,
    };

    for (final month in coveredMonths()) {
      final year = int.parse(month.split('-').first);
      final monthNo = int.parse(month.split('-').last);

      for (final entry in perFlat.entries) {
        expenses.add(Expense(
          id: 'demo_exp_electricity_${entry.key}_$month',
          flatId: entry.key,
          category: ExpenseCategory.electricity,
          amount: 4200 * entry.value,
          date: DateTime(year, monthNo, 8),
          note: 'Electricity bill',
          description: 'NEA bill for $month',
          paymentMethod: 'Bank transfer',
        ));
        expenses.add(Expense(
          id: 'demo_exp_water_${entry.key}_$month',
          flatId: entry.key,
          category: ExpenseCategory.water,
          amount: 1800 * entry.value,
          date: DateTime(year, monthNo, 9),
          note: 'Water bill',
          description: 'KUKL bill for $month',
          paymentMethod: 'Cash',
        ));
        expenses.add(Expense(
          id: 'demo_exp_internet_${entry.key}_$month',
          flatId: entry.key,
          category: ExpenseCategory.internet,
          amount: 3500 * entry.value,
          date: DateTime(year, monthNo, 5),
          note: 'Fiber internet',
          description: 'Monthly subscription',
          paymentMethod: 'Auto-debit',
        ));
      }

      // Repairs are occasional rather than monthly.
      if (monthNo.isEven) {
        expenses.add(Expense(
          id: 'demo_exp_maintenance_$month',
          flatId: 'demo_flat_a',
          category: ExpenseCategory.maintenance,
          amount: 7500,
          date: DateTime(year, monthNo, 20),
          note: 'Bathroom plumbing repair',
          description: 'Plumber visit, water tank overflow',
          paymentMethod: 'Cash',
        ));
      }
    }

    expenses.add(Expense(
      id: 'demo_exp_gas_once',
      flatId: 'demo_flat_b',
      category: ExpenseCategory.gas,
      amount: 3200,
      date: _monthDay(0, 18),
      note: 'Gas cylinder refill',
      description: null,
      paymentMethod: 'Cash',
    ));

    return expenses;
  }

  /// One paid lease cheque per covered month. Flat C is deliberately paid a
  /// month *before* its due date, which is the case that used to file the
  /// record under the wrong month.
  static List<LeaseChequeRecord> get _chequeRecords {
    final records = <LeaseChequeRecord>[];
    final specs = [
      ('demo_flat_a', 'Ramesh Maharjan', 360000.0, -2, 10, -2, 5),
      ('demo_flat_b', 'Sita Maharjan', 300000.0, -1, 15, -1, 12),
      ('demo_flat_c', 'Bishal Shrestha', 240000.0, 0, 5, -1, 28),
    ];

    for (final spec in specs) {
      final (flatId, owner, amount, dueOffset, dueDay, paidOffset, paidDay) = spec;
      records.add(LeaseChequeRecord(
        id: 'demo_cheque_$flatId',
        flatId: flatId,
        ownerName: owner,
        amount: amount,
        dueDate: _monthDay(dueOffset, dueDay),
        paidDate: _monthDay(paidOffset, paidDay),
        description: 'Annual lease cheque',
        paymentMethod: 'Cheque',
      ));
    }

    return records;
  }

  /// [day] of the month [offset] months away from the current one.
  ///
  /// Positive [offset] walks into the past (`1` = last month), negative walks
  /// forward (`-1` = next month). Used both for recorded history and for lease
  /// due dates that must still be upcoming.
  static DateTime _monthDay(int offset, int day) {
    final now = DateTime.now();
    return DateTime(now.year, now.month + offset, day);
  }
}
