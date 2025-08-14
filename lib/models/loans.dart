class Loan {
  final String id;
  final String type;
  final String name;
  final double totalAmount;
  final double? minimumPayment;
  final DateTime? dueDate;
  final double? interestRate;
  final double paymentAmountMade;
  final DateTime? payDate;
  final double amountMinusPayment;
  final String? notes;
  final bool isPriority;
  final DateTime createdAt;
  final DateTime updatedAt;

  Loan({
    required this.id,
    required this.type,
    required this.name,
    required this.totalAmount,
    this.minimumPayment,
    this.dueDate,
    this.interestRate,
    this.paymentAmountMade = 0,
    this.payDate,
    required this.amountMinusPayment,
    this.notes,
    this.isPriority = false,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Loan.fromJson(Map<String, dynamic> json) {
    return Loan(
      id: json['id'] ?? '',
      type: json['type'] ?? '',
      name: json['name'] ?? '',
      totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0.0,
      minimumPayment: (json['minimum_payment'] as num?)?.toDouble(),
      dueDate: json['due_date'] != null ? DateTime.parse(json['due_date']) : null,
      interestRate: (json['interest_rate'] as num?)?.toDouble(),
      paymentAmountMade: (json['payment_amount_made'] as num?)?.toDouble() ?? 0.0,
      payDate: json['pay_date'] != null ? DateTime.parse(json['pay_date']) : null,
      amountMinusPayment: (json['amount_minus_payment'] as num?)?.toDouble() ?? 0.0,
      notes: json['notes'],
      isPriority: json['is_priority'] ?? false,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJsonForInsert() {
    return {
      'type': type,
      'name': name,
      'total_amount': totalAmount,
      'minimum_payment': minimumPayment,
      'due_date': dueDate,
      'interest_rate': interestRate,
      'payment_amount_made': paymentAmountMade,
      'pay_date': payDate?.toIso8601String(),
      'amount_minus_payment': amountMinusPayment,
      'notes': notes,
      'is_priority': isPriority,
    };
  }

  Map<String, dynamic> toJsonForUpdate() {
    return {
      'id': id,
      'type': type,
      'name': name,
      'total_amount': totalAmount,
      'minimum_payment': minimumPayment,
      'due_date': dueDate?.toIso8601String(),
      'interest_rate': interestRate,
      'payment_amount_made': paymentAmountMade,
      'pay_date': payDate?.toIso8601String(),
      'amount_minus_payment': amountMinusPayment,
      'notes': notes,
      'is_priority': isPriority,
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  // Helper methods
  bool get hasPayment => paymentAmountMade > 0;
  bool get hasMinimumPayment => minimumPayment != null && minimumPayment! > 0;
  bool get isOverdue => dueDate != null && _isDueDatePassed();
  
  bool _isDueDatePassed() {
    if (dueDate == null) return false;
    return false; 
  }

  double get remainingBalance => totalAmount - paymentAmountMade;
}