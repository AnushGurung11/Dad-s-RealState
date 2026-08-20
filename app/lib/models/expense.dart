enum ExpenseCategory {
  electricity,
  water,
  gas,
  internet,
  repairs,
  other;

  String get label {
    switch (this) {
      case ExpenseCategory.electricity:
        return 'Electricity';
      case ExpenseCategory.water:
        return 'Water';
      case ExpenseCategory.gas:
        return 'Gas';
      case ExpenseCategory.internet:
        return 'Internet';
      case ExpenseCategory.repairs:
        return 'Repairs';
      case ExpenseCategory.other:
        return 'Other';
    }
  }

  static ExpenseCategory fromString(String value) {
    return ExpenseCategory.values.firstWhere(
      (c) => c.name == value,
      orElse: () => ExpenseCategory.other,
    );
  }
}

class Expense {
  const Expense({
    required this.id,
    required this.flatId,
    required this.category,
    required this.amount,
    required this.date,
    this.note,
  });

  final String id;
  final String flatId;
  final ExpenseCategory category;
  final double amount;
  final DateTime date;
  final String? note;

  Expense copyWith({
    String? id,
    String? flatId,
    ExpenseCategory? category,
    double? amount,
    DateTime? date,
    String? note,
  }) {
    return Expense(
      id: id ?? this.id,
      flatId: flatId ?? this.flatId,
      category: category ?? this.category,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      note: note ?? this.note,
    );
  }

  factory Expense.fromJson(Map<String, dynamic> json) {
    return Expense(
      id: json['id'] as String,
      flatId: json['flatId'] as String,
      category: ExpenseCategory.fromString(json['category'] as String),
      amount: (json['amount'] as num).toDouble(),
      date: DateTime.parse(json['date'] as String),
      note: json['note'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'flatId': flatId,
      'category': category.name,
      'amount': amount,
      'date': date.toIso8601String(),
      'note': note,
    };
  }
}